{-# LANGUAGE OverloadedStrings #-}

module AuxWire.Service.Handlers.GetHome (
  homeHandler,
) where

import Servant

import Text.Blaze.Html5 as H
import Text.Blaze.Html5.Attributes qualified as A

import Env

homeHandler :: Env -> Handler H.Html
homeHandler env =
  case env of
    DevEnv{} -> return $
      H.docTypeHtml $ do
        H.head $ do
          H.meta ! A.charset "UTF-8"
          H.meta ! A.name "viewport" ! A.content "width=device-width, initial-scale=1"
          H.link ! A.rel "icon" ! A.type_ "image/x-icon" ! A.href "vite-proxy/favicon.ico"
          H.title "Vite + Vue + TS"
          H.script ! A.type_ "module" ! A.src "vite-proxy/@vite/client" $ ""
        H.body $ do
          H.div ! A.id "app" $ ""
          H.script ! A.type_ "module" ! A.src "vite-proxy/src/pages/home/main.ts" $ ""
    ProdEnv _ _ homeHtml _ ->
      return $
        H.docTypeHtml $ do
          H.head $ do
            H.meta ! A.charset "UTF-8"
            H.meta ! A.name "viewport" ! A.content "width=device-width, initial-scale=1"
            H.link ! A.rel "icon" ! A.type_ "image/x-icon" ! A.href "public/favicon.ico"
            H.title "Vite + Vue + TS"
            H.preEscapedString homeHtml
          H.body $ do
            H.div ! A.id "app" $ ""
