{-# LANGUAGE OverloadedStrings #-}

module AuxWire.Service.Handlers.GetRoom (
  roomHandler,
) where

import Control.Monad.IO.Class
import Servant
import Text.Blaze.Html5

import Data.ByteString.Lazy.UTF8 qualified as UTF8
import Text.Blaze.Html5 qualified as H
import Text.Blaze.Html5.Attributes qualified as A

import AuxWire.Core.API
import Data.Aeson
import Env
import Network.Socket (SockAddr)

type instance UserId IO = SockAddr

initialStateScript :: (ToJSON a) => a -> H.Html
initialStateScript st =
  H.script $ preEscapedString ("window.__INITIAL_STATE__ = " ++ UTF8.toString (encode st) ++ ";")

roomHandler ::
  Env ->
  AuxWire IO ->
  RoomId ->
  UserId IO ->
  Handler H.Html
roomHandler env auxwire rId uid = do
  enterRoomResult <- liftIO $ enterRoom auxwire rId uid

  case enterRoomResult of
    Left err -> throwError $ err500{errBody = "Error: " <> UTF8.fromString err}
    Right roomState -> do
      let headScript = initialStateScript roomState
      -- {-
      -- Note: Assign hex color in backend and return in this response?
      case env of
        DevEnv{} -> return $
          H.docTypeHtml $ do
            H.head $ do
              H.meta ! A.charset "UTF-8"
              H.meta ! A.name "viewport" ! A.content "width=device-width, initial-scale=1"
              H.link ! A.rel "icon" ! A.type_ "image/x-icon" ! A.href "vite-proxy/favicon.ico"
              H.title "Vite + Vue + TS"
              H.script ! A.type_ "module" ! A.src "vite-proxy/@vite/client" $ ""
              headScript
            H.body $ do
              H.div ! A.id "app" $ ""
              H.script ! A.type_ "module" ! A.src "vite-proxy/src/pages/room/main.ts" $ ""
        ProdEnv _ _ _ roomHtml ->
          return $
            H.docTypeHtml $ do
              H.head $ do
                H.meta ! A.charset "UTF-8"
                H.meta ! A.name "viewport" ! A.content "width=device-width, initial-scale=1"
                H.link ! A.rel "icon" ! A.type_ "image/x-icon" ! A.href "public/favicon.ico"
                H.preEscapedString roomHtml
                headScript
              H.body $ do
                H.div ! A.id "app" $ ""
