{-# LANGUAGE OverloadedStrings #-}

module AuxWire.Service.Handlers.RoomWs (
  enterHandler,
) where

import Control.Monad.IO.Class
import Data.Text
import Network.Socket (SockAddr)
import Servant

import Data.ByteString.Lazy.UTF8 qualified as UTF8
import Network.WebSockets qualified as WS

import AuxWire.Core.API

type instance ConnectionRequest IO = WS.PendingConnection
type instance UserId IO = SockAddr

-- Should not terminate until the room is no longer required; because if it
-- does then the ws connection will close on the browser
enterHandler :: AuxWire IO -> UserId IO -> ConnectionRequest IO -> Handler ()
enterHandler auxwire uid pc = liftIO $ do
  results <- connectToRoomEvents auxwire uid pc

  case results of
    Left err -> error $ "Error: " <> err
    Right _ -> return ()
