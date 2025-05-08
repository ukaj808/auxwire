{-# LANGUAGE OverloadedStrings #-}

module AuxWire.Core.API where

import Data.Aeson.Types
import Data.Kind
import Data.Maybe

import Data.Aeson qualified as Aeson

data AuxWire m = AuxWire
  { createRoom :: UserId m -> m (Either String RoomId)
  , enterRoom :: RoomId -> UserId m -> m (Either String (RoomState m))
  , connectToRoomEvents :: UserId m -> ConnectionRequest m -> m (Either String ())
  , connectToMusicStream :: UserId m -> ConnectionRequest m -> m (Either String ())
  , startMusic :: UserId m -> m (Either String ())
  , uploadSong :: UserId m -> Upload m -> m (Either String ())
  }

data Upload m = UrlUpload String | FileUpload (AudioFile m)

data DjState m = Streaming {djProcessId :: DjProcessId m, songId :: SongId} | Countdown {djProcessId :: DjProcessId m, countdownTimer :: Int} | Polling {djProcessId :: DjProcessId m} | Uploading {djProcessId :: DjProcessId m} | Starting | NotRunning

instance ToJSON (User m) where
  toJSON :: User m -> Value
  toJSON u =
    Aeson.object
      [ "userName" .= userName u
      , "hexColor" .= userHexColor u
      , "isAdmin" .= isAdmin u
      , "connectedToRoomEvents" .= isJust (roomStateChangeConnection u)
      , "connectedToMusicStream" .= isJust (musicStreamConnection u)
      ]

data User m = User
  { userId :: UserId m
  , userName :: UserName
  , userHexColor :: String
  , roomStateChangeConnectionInitiated :: Bool
  , roomStateChangeConnection :: Maybe (Connection m)
  , musicStreamConnectionInitiated :: Bool
  , musicStreamConnection :: Maybe (Connection m)
  , isAdmin :: Bool
  }

data UserMusicStream m = UserMusicStream
  { musicStreamConn :: Connection m
  , musicStreamState :: UserMusicStreamState
  }

data UserMusicStreamState = Consuming | Waiting
  deriving (Eq, Show)

-- A sanitized view of the room
data RoomState m = RoomState
  { roomDjState :: DjState m
  , roomUsers :: [User m]
  , roomAdminId :: UserId m
  }

instance ToJSON (RoomState m) where
  toJSON :: RoomState m -> Value
  toJSON roomState =
    Aeson.object
      [ "djState" .= roomDjState roomState
      , "users" .= roomUsers roomState
      ]

-- Message from server to user
data ServerCommand = ServerUploadSongCommand

newtype UserEvent = UserAudioPrepared UserName

type RoomId = String
type SongId = String
type UserName = String
type Vote = Bool

type family ConnectionRequest (m :: Type -> Type) :: Type
type family Connection (m :: Type -> Type) :: Type
type family SongFile (m :: Type -> Type) :: Type
type family UserId (m :: Type -> Type) :: Type
type family DjProcessId (m :: Type -> Type) :: Type
type family RoomStorage (m :: Type -> Type) :: Type
type family AudioFile (m :: Type -> Type) :: Type

instance ToJSON (DjState m) where
  toJSON :: DjState m -> Value
  toJSON (Streaming _ sid) =
    Aeson.object
      [ "songId" .= sid
      , "status" .= ("streaming" :: String)
      ]
  toJSON (Countdown _ timer) =
    Aeson.object
      [ "timer" .= timer
      , "status" .= ("countdown" :: String)
      ]
  toJSON (Polling _) =
    Aeson.object ["status" .= ("polling" :: String)]
  toJSON Starting =
    Aeson.object ["status" .= ("starting" :: String)]
  toJSON NotRunning =
    Aeson.object ["status" .= ("not-running" :: String)]
