{-# LANGUAGE OverloadedStrings #-}

module AuxWire.Service.Handlers.PutStartMusic (
  startHandler,
) where

import Control.Monad.IO.Class
import Network.Socket (SockAddr)
import Servant

import Data.ByteString.Lazy.UTF8 qualified as UTF8

import AuxWire.Core.API

type instance UserId IO = SockAddr

startHandler :: AuxWire IO -> UserId IO -> Handler NoContent
startHandler auxwire uid = do
  startMusicResult <- liftIO $ startMusic auxwire uid

  case startMusicResult of
    Left err -> throwError $ err500{errBody = "Error: " <> UTF8.fromString err}
    Right _ -> return NoContent
