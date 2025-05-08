module Main (main) where

import AuxWire.Core.IO
import AuxWire.Service.Application
import Env
import Network.Wai.Handler.Warp
import Network.Wai.Handler.WarpTLS
import Network.Wai.Middleware.ForceSSL
import System.IO.Temp (withTempDirectory)

main :: IO ()
main = do
  env <- buildEnv
  withTempDirectory
    "."
    "rooms"
    $ \roomsPath -> do
      auxwire <- initAuxWire roomsPath
      runTLS (tlsOpts (cert env) (key env)) warOpts $
        forceSSL $
          server env auxwire
 where
  port = 8443
  tlsOpts crt privKey = (tlsSettings crt privKey){onInsecure = AllowInsecure}
  warOpts = setPort port defaultSettings
