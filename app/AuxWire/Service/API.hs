{-# LANGUAGE OverloadedStrings #-}

module AuxWire.Service.API (
  API,
  EnqueueSongRequest (..),
  ValidateUrlRequest (..),
  ServerHtml,
  StaticHtml (..),
  StaticJs (..),
) where

import Data.Aeson
import GHC.Generics
import Network.HTTP.Media
import Servant
import Servant.API.WebSocket
import Servant.HTML.Blaze
import Servant.Multipart
import Text.Blaze.Html5

import Data.ByteString.Lazy qualified as Lazy

import AuxWire.Core.API

type ServerHtml = Html

data JS = JS

newtype StaticHtml = StaticHtml
  { unrawHtml :: String
  }
newtype StaticJs = StaticJs
  { unrawJs :: Lazy.ByteString
  }

instance MimeRender JS StaticJs where
  mimeRender _ = unrawJs

instance Servant.Accept JS where
  contentType _ = "text" // "javascript" /: ("charset", "utf-8")

instance ToMarkup StaticHtml where
  toMarkup = preEscapedToMarkup
  preEscapedToMarkup st = preEscapedString $ unrawHtml st

type PostSeeOther = Verb 'POST 303

newtype ValidateUrlRequest = ValidateUrlRequest
  { url :: String
  }
  deriving (Generic, Show)
instance FromJSON ValidateUrlRequest

newtype EnqueueSongRequest = EnqueueSongRequest
  { priority :: Int
  }
  deriving (Generic)
instance FromJSON EnqueueSongRequest

type API =
  Get '[HTML] Html -- Home Page
  -- Create Room Button Click on Home Page -> Create Room -> Redirect to /room/<id>
    :<|> RemoteHost :> PostSeeOther '[PlainText] (Headers '[Header "Location" String] NoContent)
    :<|> Capture "roomid" String :> RemoteHost :> Get '[HTML] Html
    :<|> "ws" :> RemoteHost :> WebSocketPending
    :<|> "music" :> RemoteHost :> WebSocketPending
    :<|> "start" :> RemoteHost :> PutNoContent
    :<|> "upload" :> MultipartForm Tmp (MultipartData Tmp) :> RemoteHost :> PutNoContent
    :<|> "validate-url" :> ReqBody '[JSON] ValidateUrlRequest :> Post '[PlainText] String
    :<|> "public" :> Raw

-- maybe scrape request comes through websockets because there only passing a url...
-- Need more endpoints for music file download + delete
