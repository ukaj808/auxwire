{-# LANGUAGE OverloadedStrings #-}

module AuxWire.Service.Application (server) where

import Servant

import AuxWire.Core.API
import AuxWire.Service.API
import AuxWire.Service.Handlers.GetHome
import AuxWire.Service.Handlers.GetRoom
import AuxWire.Service.Handlers.MusicWs
import AuxWire.Service.Handlers.PostHome
import AuxWire.Service.Handlers.PostValidateUrl
import AuxWire.Service.Handlers.PutStartMusic
import AuxWire.Service.Handlers.PutUploadSong
import AuxWire.Service.Handlers.RoomWs
import Commons.Vite
import Env
import Network.HTTP.Types
import Network.Wai

handlers :: Env -> AuxWire IO -> Server API
handlers env auxwire =
  homeHandler env
    :<|> createHandler auxwire
    :<|> roomHandler env auxwire
    :<|> enterHandler auxwire
    :<|> connectHandler auxwire
    :<|> startHandler auxwire
    :<|> uploadHandler auxwire
    :<|> validateHandler
    :<|> publicHandler
 where
  publicHandler = serveDirectoryWebApp "./client-side/dist"

defaultHeadersMiddleware :: Middleware
defaultHeadersMiddleware app req sendResponse =
  app req $ \res -> do
    sendResponse $ mapResponseHeaders (defaultHeaders ++) res

allMiddlewares :: Env -> Middleware
allMiddlewares env =
  defaultHeadersMiddleware
    . viteProxyMiddleware (ViteProxySettings (isDev env) ["vite-proxy"] 5173 True)

defaultHeaders :: ResponseHeaders
defaultHeaders =
  [ ("Cross-Origin-Opener-Policy", "same-origin")
  , ("Cross-Origin-Embedder-Policy", "require-corp")
  ]

server :: Env -> AuxWire IO -> Application
server env rr = allMiddlewares env $ serve (Proxy @API) (handlers env rr)
