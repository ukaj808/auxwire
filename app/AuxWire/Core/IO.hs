module AuxWire.Core.IO (
  initAuxWire,
) where

import Commons.FFMpeg
import Commons.Wav
import Control.Concurrent
import Control.Monad
import Data.Colour.Palette.RandomColor
import Data.Colour.SRGB
import Data.UUID
import Data.UUID.V4
import GHC.IO
import Network.Socket
import System.Directory
import System.IO

import Data.Aeson qualified as Aeson
import Data.ByteString qualified as B
import Data.List qualified as List
import Data.Map qualified as Map
import Data.Text qualified as T
import Network.WebSockets qualified as WS

import AuxWire.Core.API
import Servant.Multipart
import System.FilePath

import Control.Concurrent.STM

type instance UserId IO = SockAddr
type instance ConnectionRequest IO = WS.PendingConnection
type instance Connection IO = WS.Connection
type instance DjProcessId IO = ThreadId
type instance RoomStorage IO = FilePath
type instance AudioFile IO = FileData Tmp

type RoomMap = Map.Map RoomId (RoomState IO)

type RoomsTVar = TVar RoomMap

data AuxWireInternals = AuxWireInternals
  { roomsTVar :: RoomsTVar
  , roomStateChangeTQueue :: TQueue (RoomId, RoomState IO)
  , roomStateChangeConsumerThreadId :: ThreadId
  }

initAuxWire :: FilePath -> IO (AuxWire IO)
initAuxWire dir = do
  createDirectory dir
  roomsTVar <- newTVarIO Map.empty
  roomStateChangeTQueue <- newTQueueIO :: IO (TQueue (RoomId, RoomState IO))
  roomStateChangeConsumerThreadId <- forkIO $ forever $ do
    roomStateChange <- atomically $ readTQueue roomStateChangeTQueue
    publishRoomStateChange roomStateChange
  let auxWireInternals =
        AuxWireInternals
          { roomsTVar = roomsTVar
          , roomStateChangeTQueue = roomStateChangeTQueue
          , roomStateChangeConsumerThreadId = roomStateChangeConsumerThreadId
          }
  return $
    AuxWire
      { createRoom = createRoomImpl auxWireInternals dir
      , enterRoom = enterRoomImpl auxWireInternals
      , connectToRoomEvents = connectToRoomEventsImpl auxWireInternals
      , connectToMusicStream = connectToMusicStreamImpl auxWireInternals
      , startMusic = startMusicImpl auxWireInternals
      , uploadSong = uploadSongImpl auxWireInternals dir
      }

createRoomImpl :: AuxWireInternals -> FilePath -> UserId IO -> IO (Either String RoomId)
createRoomImpl internals dir uid =
  do
    rid <- toString <$> nextRandom
    res <- atomically $ do
      rooms <- readTVar (roomsTVar internals)
      let userAndRoom = findUserAndRoom uid rooms
      case userAndRoom of
        Right _ -> return $ Left $ "User already in an existing room"
        Left _ -> do
          let newRoomState =
                RoomState
                  { roomDjState = NotRunning
                  , roomUsers = []
                  , roomAdminId = uid
                  } ::
                  RoomState IO
          let rooms' = Map.insert rid newRoomState rooms
          writeTVar (roomsTVar internals) rooms'
          return $ Right rid
    case res of
      Left _ -> return res
      Right _ -> do
        -- could fail technically, then we have a room without a directory
        -- bracket this, update state, then return error
        createDirectory (dir </> rid)
        return res

enterRoomImpl :: AuxWireInternals -> RoomId -> UserId IO -> IO (Either String (RoomState IO))
enterRoomImpl internals rid uid = do
  hex <- (sRGB24shows <$> randomCIELab) <*> pure ""
  atomically $ do
    rooms <- readTVar $ roomsTVar internals
    let userAndRoom = findUserAndRoom uid rooms
    case userAndRoom of
      Right _ -> return $ Left "User already in a room"
      Left _ -> do
        case Map.lookup rid rooms of
          Nothing -> return $ Left "Room not found"
          Just roomState -> do
            let newRoomState = roomState{roomUsers = roomUsers roomState ++ [User uid hex hex False Nothing False Nothing (uid == roomAdminId roomState)]}
            let updatedRooms = Map.insert rid newRoomState rooms
            writeTVar (roomsTVar internals) updatedRooms
            writeTQueue (roomStateChangeTQueue internals) (rid, newRoomState)
            return $ Right newRoomState

connectToRoomEventsImpl :: AuxWireInternals -> UserId IO -> ConnectionRequest IO -> IO (Either String ())
connectToRoomEventsImpl internals uid connReq = do
  connectionCheckResult <-
    atomically $ do
      rooms <- readTVar (roomsTVar internals)
      let userAndRoom = findUserAndRoom uid rooms
      case userAndRoom of
        Left err -> return $ Left err
        Right (userState, rid, roomState) ->
          case (roomStateChangeConnectionInitiated userState, roomStateChangeConnection userState) of
            (True, _) -> return $ Left "User already in the process of connecting to room events"
            (_, Just _) -> return $ Left "User already connected to room events"
            _ -> do
              let updatedUserState = userState{roomStateChangeConnectionInitiated = True}
              let updatedRoomState = roomState{roomUsers = map (\u -> if userId u == uid then updatedUserState else u) (roomUsers roomState)}
              let updatedRoomMapState = Map.insert rid updatedRoomState rooms
              writeTVar (roomsTVar internals) updatedRoomMapState
              writeTQueue (roomStateChangeTQueue internals) (rid, updatedRoomState)
              return $ Right ()
  case connectionCheckResult of
    Left _ -> return connectionCheckResult
    Right _ -> do
      conn <- WS.acceptRequest connReq
      res <- atomically $ do
        rooms <- readTVar (roomsTVar internals)
        let userAndRoom = findUserAndRoom uid rooms
        case userAndRoom of
          Left err -> return $ Left err
          Right (userState, rid, roomState) -> do
            let updatedUserState = userState{roomStateChangeConnection = Just conn}
            let updatedRoomState = roomState{roomUsers = map (\u -> if userId u == uid then updatedUserState else u) (roomUsers roomState)}
            let updatedRoomMapState = Map.insert rid updatedRoomState rooms
            writeTVar (roomsTVar internals) updatedRoomMapState
            writeTQueue (roomStateChangeTQueue internals) (rid, updatedRoomState)
            return $ Right ()
      WS.withPingThread conn 30 (return ()) $
        finally (throwMessagesAway conn) disconnect
 where
  throwMessagesAway conn = do
    forever $ do
      _ <- WS.receiveDataMessage conn
      return ()
  disconnect = do
    -- This is how we detect if a user left the room...
    shouldKillDjThread <- atomically $ do
      rooms <- readTVar (roomsTVar internals)
      let userAndRoom = findUserAndRoom uid rooms
      case userAndRoom of
        Left _ -> return $ Left "This should not happen! (Err: 1)"
        Right (_, rid, roomState) -> do
          case roomUsers roomState of
            [] -> return $ Left "This should not happen! (Err: 2)"
            [_] -> do
              let updatedRoomMapState = Map.delete rid rooms
              writeTVar (roomsTVar internals) updatedRoomMapState
              case roomDjState roomState of
                Countdown tid _ -> return $ Right (Just tid)
                Polling tid -> return $ Right (Just tid)
                Streaming tid _ -> return $ Right (Just tid)
                _ -> return $ Right Nothing
            (x : _) -> do
              let updatedRoomState =
                    roomState
                      { roomUsers = filter (\u -> userId u /= uid) (roomUsers roomState)
                      , roomAdminId = if uid == roomAdminId roomState then userId x else roomAdminId roomState
                      }
              let updatedRoomMapState = Map.insert rid updatedRoomState rooms
              writeTVar (roomsTVar internals) updatedRoomMapState
              writeTQueue (roomStateChangeTQueue internals) (rid, updatedRoomState)
              return $ Right Nothing
    case shouldKillDjThread of
      Left err -> putStrLn err
      Right Nothing -> return ()
      Right (Just tid) -> killThread tid

connectToMusicStreamImpl :: AuxWireInternals -> UserId IO -> ConnectionRequest IO -> IO (Either String ())
connectToMusicStreamImpl internals uid connReq = do
  connectionCheckResult <- atomically $ do
    rooms <- readTVar (roomsTVar internals)
    let userAndRoom = findUserAndRoom uid rooms
    case userAndRoom of
      Left err -> return $ Left err
      Right (userState, rid, roomState) ->
        case (musicStreamConnectionInitiated userState, musicStreamConnection userState) of
          (True, _) -> return $ Left "User already in the process of connecting to the music stream"
          (_, Just _) -> return $ Left "User already connected to the music stream"
          _ -> do
            let updatedUserState = userState{musicStreamConnectionInitiated = True}
            let updatedRoomState = roomState{roomUsers = map (\u -> if userId u == uid then updatedUserState else u) (roomUsers roomState)}
            let updatedRoomMapState = Map.insert rid updatedRoomState rooms
            writeTVar (roomsTVar internals) updatedRoomMapState
            writeTQueue (roomStateChangeTQueue internals) (rid, updatedRoomState)
            return $ Right ()
  case connectionCheckResult of
    Left _ -> return connectionCheckResult
    Right _ -> do
      conn <- WS.acceptRequest connReq
      res <- atomically $ do
        rooms <- readTVar (roomsTVar internals)
        let userAndRoom = findUserAndRoom uid rooms
        case userAndRoom of
          Left err -> return $ Left err
          Right (userState, rid, roomState) -> do
            let updatedUserState = userState{musicStreamConnection = Just conn}
            let updatedRoomState = roomState{roomUsers = map (\u -> if userId u == uid then updatedUserState else u) (roomUsers roomState)}
            let updatedRoomMapState = Map.insert rid updatedRoomState rooms
            writeTVar (roomsTVar internals) updatedRoomMapState
            writeTQueue (roomStateChangeTQueue internals) (rid, updatedRoomState)
            return $ Right ()
      WS.withPingThread conn 30 (return ()) $
        finally (throwMessagesAway conn) disconnect
 where
  throwMessagesAway conn = do
    forever $ do
      _ <- WS.receiveDataMessage conn
      return ()
  disconnect = do
    -- This is how we detect if a user left the room...
    shouldKillDjThread <- atomically $ do
      rooms <- readTVar (roomsTVar internals)
      let userAndRoom = findUserAndRoom uid rooms
      case userAndRoom of
        Left _ -> return $ Left "This should not happen! (Err: 1)"
        Right (_, rid, roomState) -> do
          case roomUsers roomState of
            [] -> return $ Left "This should not happen! (Err: 2)"
            [_] -> do
              let updatedRoomMapState = Map.delete rid rooms
              writeTVar (roomsTVar internals) updatedRoomMapState
              case roomDjState roomState of
                Countdown tid _ -> return $ Right (Just tid)
                Polling tid -> return $ Right (Just tid)
                Streaming tid _ -> return $ Right (Just tid)
                _ -> return $ Right Nothing
            (x : _) -> do
              let updatedRoomState =
                    roomState
                      { roomUsers = filter (\u -> userId u /= uid) (roomUsers roomState)
                      , roomAdminId = if uid == roomAdminId roomState then userId x else roomAdminId roomState
                      }
              let updatedRoomMapState = Map.insert rid updatedRoomState rooms
              writeTVar (roomsTVar internals) updatedRoomMapState
              writeTQueue (roomStateChangeTQueue internals) (rid, updatedRoomState)
              return $ Right Nothing
    case shouldKillDjThread of
      Left err -> putStrLn err
      Right Nothing -> return ()
      Right (Just tid) -> killThread tid

startMusicImpl :: AuxWireInternals -> UserId IO -> IO (Either String ())
startMusicImpl internals uid = do
  startCheckResult <- atomically $ do
    rooms <- readTVar (roomsTVar internals)
    let userAndRoom = findUserAndRoom uid rooms
    case userAndRoom of
      Left err -> return $ Left err
      Right (_, rid, roomState)
        | uid == roomAdminId roomState ->
            case roomDjState roomState of
              NotRunning -> do
                let updatedRoomState = roomState{roomDjState = Starting}
                let updatedRoomMapState = Map.insert rid updatedRoomState rooms
                writeTVar (roomsTVar internals) updatedRoomMapState
                writeTQueue (roomStateChangeTQueue internals) (rid, updatedRoomState)
                return $ Right rid
              _ -> return $ Left "Room music already started"
        | otherwise -> return $ Left "User is not the admin of the room"
  case startCheckResult of
    Left err -> return $ Left err
    Right rid -> do
      djThreadId <- forkIO $ goDj internals rid
      atomically $ do
        rooms <- readTVar (roomsTVar internals)
        let room = Map.lookup rid rooms
        case room of
          Nothing -> return $ Left "Room not found (Err: 1)"
          Just roomState -> do
            let updatedRoomState = roomState{roomDjState = Countdown djThreadId 5}
            let updatedRoomMapState = Map.insert rid updatedRoomState rooms
            writeTVar (roomsTVar internals) updatedRoomMapState
            writeTQueue (roomStateChangeTQueue internals) (rid, updatedRoomState)
            return $ Right ()

uploadSongImpl :: AuxWireInternals -> FilePath -> UserId IO -> Upload m -> IO (Either String ())
uploadSongImpl internals dir uid upload = do
  uploadCheckResult <- atomically $ do
    rooms <- readTVar (roomsTVar internals)
    let userAndRoom = findUserAndRoom uid rooms
    case userAndRoom of
      Left err -> return $ Left err
      Right (_, rid, roomState) ->
        case (roomDjState roomState, roomUsers roomState) of
          (Polling tid, u : _) ->
            if uid == userId u
              then do
                let updatedRoomState = roomState{roomDjState = Uploading tid}
                let updatedRoomMapState = Map.insert rid updatedRoomState rooms
                writeTVar (roomsTVar internals) updatedRoomMapState
                writeTQueue (roomStateChangeTQueue internals) (rid, updatedRoomState)
                return $ Right rid
              else return $ Left "It's not your turn to upload a song"
          _ -> return $ Left "Room is not in a state to upload a song"
  case uploadCheckResult of
    Left err -> return $ Left err
    Right rid -> do
      copyFile (uploadTmp upload) (dir </> rid </> uploadName upload)
      return $ Right ()

goDj :: AuxWireInternals -> RoomId -> IO ()
goDj internals rid = do
  threadId <- myThreadId
  forM_ [5, 4, 3, 2, 1, 0] $ \i -> do
    countdownIterationResult <- atomically $ do
      rooms <- readTVar (roomsTVar internals)
      let room = Map.lookup rid rooms
      case room of
        Nothing -> return $ Left "Room not found during countdown" -- throw error
        Just roomState -> do
          let newRoomState = roomState{roomDjState = Countdown threadId i}
          let updatedRoomMapState = Map.insert rid newRoomState rooms
          writeTVar (roomsTVar internals) updatedRoomMapState
          writeTQueue (roomStateChangeTQueue internals) (rid, newRoomState)
          return $ Right ()
    -- handle error?
    threadDelay 1000000

  pollingIterationResult <- atomically $ do
    rooms <- readTVar (roomsTVar internals)
    let room = Map.lookup rid rooms
    case room of
      Nothing -> return $ Left "Room not found during polling" -- throw error
      Just roomState -> do
        let newRoomState = roomState{roomDjState = Polling threadId}
        let updatedRoomMapState = Map.insert rid newRoomState rooms
        writeTVar (roomsTVar internals) updatedRoomMapState
        writeTQueue (roomStateChangeTQueue internals) (rid, newRoomState)
        return $ Right ()

  polled <- pollSongIsUploaded internals rid 60
  -- refresh st var; users could have joined during polling... maybe should redo this
  maybeFile <- atomically $ do
    rooms <- readTVar (roomsTVar internals)
    let room = Map.lookup rid rooms
    case room of
      Nothing -> return $ Left "Room not found after polling" -- throw error
      Just roomState -> do
        case polled of
          Left err -> return $ Left err
          Right Nothing ->
            case roomUsers roomState of
              [] -> return $ Left "No users in queue after polling"
              (nextUp : rest) -> do
                let newRoomState =
                      roomState
                        { roomUsers = rest ++ [nextUp]
                        }
                let updatedRoomMapState = Map.insert rid newRoomState rooms
                writeTVar (roomsTVar internals) updatedRoomMapState
                writeTQueue (roomStateChangeTQueue internals) (rid, newRoomState)
                return $ Right Nothing
          Right (Just file) -> do
            let newRoomState = roomState{roomDjState = Streaming threadId file}
            let updatedRoomMapState = Map.insert rid newRoomState rooms
            writeTVar (roomsTVar internals) updatedRoomMapState
            writeTQueue (roomStateChangeTQueue internals) (rid, newRoomState)
            return $ Right (Just file)

  case maybeFile of
    Left err -> putStrLn err
    Right Nothing -> goDj internals rid
    Right (Just file) -> do
      stream internals rid file
      postStream <- atomically $ do
        rooms <- readTVar (roomsTVar internals)
        let room = Map.lookup rid rooms
        case room of
          Nothing -> return $ Left "Room not found after streaming" -- throw error
          Just roomState ->
            case roomUsers roomState of
              [] -> return $ Left "No users in queue after streaming"
              (nextUp : rest) -> do
                let newRoomState =
                      roomState
                        { roomUsers = rest ++ [nextUp]
                        }
                let updatedRoomMapState = Map.insert rid newRoomState rooms
                writeTVar (roomsTVar internals) updatedRoomMapState
                writeTQueue (roomStateChangeTQueue internals) (rid, newRoomState)
                return $ Right ()

      case postStream of
        Left err -> do
          putStrLn err
          goDj internals rid
        Right () -> do
          goDj internals rid

-- todo: deal with async threads
-- we should keep a reference to the thread so when room is empty we can terminate it

-- Messaging Via Websockets

publishRoomStateChange :: (RoomId, RoomState IO) -> IO ()
publishRoomStateChange (roomId, roomState) = do
  forM_ (roomUsers roomState) $ \u ->
    case roomStateChangeConnection u of
      Nothing -> putStrLn "No connection for user"
      Just conn ->
        catch
          (WS.sendTextData conn (Aeson.encode roomState))
          ( \e -> do
              case e of
                WS.ConnectionClosed -> putStrLn $ "Connection closed for user: " ++ show u
                _ -> putStrLn $ "Error sending message to user: " ++ show u
          )

pollSongIsUploaded :: AuxWireInternals -> RoomId -> Int -> IO (Either String (Maybe String))
pollSongIsUploaded _ _ 0 = return $ Right Nothing
pollSongIsUploaded internals rid retryAttempts = do
  rooms <- readTVarIO (roomsTVar internals)
  let room = Map.lookup rid rooms
  case room of
    Nothing -> return $ Left "Room not found during polling"
    Just roomState ->
      case roomDjState roomState of
        Uploading _ -> do
          threadDelay 1000000
          pollSongIsUploaded internals rid (retryAttempts - 1)
        Polling _ -> do
          threadDelay 1000000
          pollSongIsUploaded internals rid (retryAttempts - 1)
        Streaming _ fileName -> return $ Right (Just fileName)
        _ -> return $ Left "Room is not in a state to upload a song"

findUserAndRoom :: UserId IO -> RoomMap -> Either String (User IO, RoomId, RoomState IO)
findUserAndRoom uid rooms =
  let maybeRoom =
        List.find
          ( \(_, roomState) ->
              List.any (\(u :: User IO) -> userId u == uid) (roomUsers roomState)
          )
          (Map.toList rooms)
   in case maybeRoom of
        Nothing -> Left "User not found in any room"
        Just (rid, roomState) ->
          case List.find (\u -> userId u == uid) (roomUsers roomState) of
            Nothing -> error "Not theoretically possible"
            Just u -> Right (u, rid, roomState)

findAndUpdateInPlace :: (a -> Bool) -> (a -> a) -> [a] -> Maybe (a, [a])
findAndUpdateInPlace predi update xs =
  case findAndUpdate xs of
    (Nothing, _) -> Nothing
    (Just x, xs') -> Just (x, xs')
 where
  findAndUpdate =
    foldr
      ( \x (found, ys) ->
          case found of
            Just _ -> (found, x : ys)
            Nothing ->
              if predi x
                then
                  (Just $ update x, update x : ys)
                else
                  (found, x : ys)
      )
      (Nothing, [])

stream :: AuxWireInternals -> RoomId -> FilePath -> IO ()
stream internals rid file = do
  let fileName = takeBaseName file
  let fileExt = takeExtension file
  wavFile <- convertToWav "ffmpeg" file fileName fileExt
  readHandle <- openFile wavFile ReadMode
  (fmtSubChunk, rawFmtSubChunk, audioByteLength) <- parseWavFile readHandle

  rooms <- readTVarIO (roomsTVar internals)
  {-
   - Is this ok? Read the state once; and stream to connected users?
   -}
  let maybeRoom = Map.lookup rid rooms
  case maybeRoom of
    Nothing -> putStrLn "Room not found"
    Just roomState -> do
      forM_ (roomUsers roomState) $ \u ->
        case musicStreamConnection u of
          Nothing -> putStrLn "No connection for user"
          Just conn -> WS.sendBinaryData conn rawFmtSubChunk

      streamChunks fmtSubChunk readHandle audioByteLength

      removeFile wavFile

      forM_ (roomUsers roomState) $ \u -> do
        case musicStreamConnection u of
          Nothing -> putStrLn "No connection for user"
          Just musicStream -> WS.sendBinaryData musicStream (B.pack [0])

      waitUntilAllHaveConsumed internals rid
 where
  streamChunks :: FmtSubChunk -> Handle -> Integer -> IO ()
  streamChunks _ _ bytesLeft | bytesLeft <= 0 = return ()
  streamChunks fmtSubChunk readHandle bytesLeft = do
    let chunkSize = fromIntegral $ byteRate fmtSubChunk `div` 8
    let delay = 1000000 `div` 8
    chunk <- B.hGet readHandle chunkSize
    rooms <- readTVarIO (roomsTVar internals)
    {-
    - Is this ok? Read the state once; and stream to connected users?
    -}
    let maybeRoom = Map.lookup (takeBaseName file) rooms
    case maybeRoom of
      Nothing -> putStrLn "Room not found"
      Just roomState -> do
        forM_ (roomUsers roomState) $ \u ->
          case musicStreamConnection u of
            Nothing -> putStrLn "No connection for user"
            Just conn -> WS.sendBinaryData conn chunk
    threadDelay delay
    streamChunks fmtSubChunk readHandle (bytesLeft - toInteger chunkSize)

waitUntilAllHaveConsumed :: AuxWireInternals -> RoomId -> IO ()
waitUntilAllHaveConsumed internals rid = do
  rooms <- readTVarIO (roomsTVar internals)
  let maybeRoom = Map.lookup rid rooms
  case maybeRoom of
    Nothing -> return ()
    Just roomState -> do
      if areAllWaiting roomState
        then
          return ()
        else waitUntilAllHaveConsumed internals rid

areAllWaiting :: RoomState IO -> Bool
areAllWaiting st = True

-- areAllWaiting st = Map.foldl (\acc session -> acc && (streamState session == Waiting)) True (streams st)
--
instance Show (User IO) where
  show u = show $ userId u

-- MVar Model
-- An event takes place on a thread that grabs the lock
-- updates the state, then releases the lock, then synchronously broadcasts
-- the state update to the room
-- In the mean while, any read calls to the state will wake up once the lock released
-- Another event takes place at the same time on another thread
-- but was second to the lock, so it waits; when it wakes up
-- it applies the state update then synchronously broadcasts the event
