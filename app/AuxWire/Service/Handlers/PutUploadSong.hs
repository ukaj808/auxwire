{-# LANGUAGE OverloadedStrings #-}

module AuxWire.Service.Handlers.PutUploadSong (
  uploadHandler,
) where

import Control.Monad.Cont
import Network.Socket (SockAddr)
import Servant
import Servant.Multipart

import Data.Text qualified as T

import AuxWire.Core.API

type instance UserId IO = SockAddr
type instance AudioFile IO = FileData Tmp

uploadHandler :: AuxWire IO -> MultipartData Tmp -> UserId IO -> Handler NoContent
uploadHandler auxwire mlt uid = do
  let parseFile = lookupFile "file" mlt
  let parseUrl = lookupInput "url" mlt

  result <- case (parseFile, parseUrl) of
    (Left _, Left _) -> throwError err400
    (Right _, Right _) -> throwError err400
    (Right fileData, Left _) -> do
      liftIO $ putStrLn $ fdPayload fileData
      liftIO $
        uploadSong auxwire uid $
          FileUpload fileData
    (Left _, Right url) -> do
      liftIO $ putStrLn (T.unpack url)
      liftIO $
        uploadSong auxwire uid $
          UrlUpload (T.unpack url)

  case result of
    Left err -> do
      liftIO $ putStrLn err
      throwError err500
    Right _ -> do
      return NoContent
