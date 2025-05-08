{-# LANGUAGE OverloadedStrings #-}

module AuxWire.Service.Handlers.PostHome (
  createHandler,
) where

import Control.Monad.IO.Class
import Network.Socket (SockAddr)
import Servant

import Data.ByteString.Lazy.UTF8 qualified as UTF8

import AuxWire.Core.API

type instance UserId IO = SockAddr

createHandler :: AuxWire IO -> UserId IO -> Handler (Headers '[Header "Location" String] NoContent)
createHandler auxwire uid = do
  createRoomResult <- liftIO $ createRoom auxwire uid

  case createRoomResult of
    Left err -> throwError $ err500{errBody = "Error: " <> UTF8.fromString err}
    Right rid -> return $ addHeader (genLocation rid) NoContent

genLocation :: RoomId -> String
genLocation = (:) '/'
