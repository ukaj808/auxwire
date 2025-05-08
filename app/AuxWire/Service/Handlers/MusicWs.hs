{-# LANGUAGE OverloadedStrings #-}

module AuxWire.Service.Handlers.MusicWs (
  connectHandler,
) where

import Control.Monad.IO.Class
import Network.Socket (SockAddr)
import Servant

import Data.ByteString.Lazy.UTF8 qualified as UTF8
import Network.WebSockets qualified as WS

import AuxWire.Core.API

type instance ConnectionRequest IO = WS.PendingConnection
type instance UserId IO = SockAddr

-- Should not terminate until the room is no longer required; because if it
-- does then the ws connection will close on the browser
connectHandler :: AuxWire IO -> SockAddr -> ConnectionRequest IO -> Handler ()
connectHandler auxwire uid pc = liftIO $ do
  connectToMusicStreamResult <- liftIO $ connectToMusicStream auxwire uid pc
  case connectToMusicStreamResult of
    Left err -> error $ "Error connecting to music stream: " ++ show err
    Right _ -> return ()
