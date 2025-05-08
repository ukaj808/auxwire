module AuxWire.Service.Handlers.PostValidateUrl (
  validateHandler,
) where

import Control.Monad.Cont
import Data.Text
import Servant

import AuxWire.Service.API
import Commons.YtDlp

validateHandler :: ValidateUrlRequest -> Handler String
validateHandler req = liftIO $ ytdlpValid "yt-dlp" (url req)
