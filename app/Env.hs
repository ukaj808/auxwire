module Env (
  Env (..),
  SupportedEnv (..),
  buildEnv,
  isDev,
  isProd,
) where

import Commons.Vite
import Data.Aeson
import Options.Applicative

import Data.ByteString.Lazy qualified as LBS

data SupportedEnv = Dev | Prod
  deriving (Show)

instance Read SupportedEnv where
  readsPrec _ "dev" = [(Dev, "")]
  readsPrec _ "prod" = [(Prod, "")]
  readsPrec _ _ = error "Invalid environment"

data Env
  = DevEnv {cert :: FilePath, key :: FilePath}
  | ProdEnv {cert :: FilePath, key :: FilePath, homeHtml :: String, roomHtml :: String}

data CLArgs
  = CLArgs
  { env :: SupportedEnv
  , certificatePath :: FilePath
  , privateKeyPath :: FilePath
  }
  deriving (Show)

isDev :: Env -> Bool
isDev (DevEnv{}) = True
isDev (ProdEnv{}) = False

isProd :: Env -> Bool
isProd = not . isDev

parseOptions :: Parser CLArgs
parseOptions =
  CLArgs
    <$> parseEnv
    <*> parseCertificatePath
    <*> parsePrivateKeyPath

parseEnv :: Parser SupportedEnv
parseEnv =
  option auto $
    mconcat
      [ long "env"
      , short 'e'
      , help "Environment"
      ]

parseStaticAssetsPath :: Parser FilePath
parseStaticAssetsPath =
  option str $
    mconcat
      [ long "path-to-static-files"
      , short 'p'
      , help "Directory of the static files"
      ]

parseCertificatePath :: Parser FilePath
parseCertificatePath =
  option str $
    mconcat
      [ long "certificate-path"
      , short 'c'
      , help "Path to the certificate"
      ]

parsePrivateKeyPath :: Parser FilePath
parsePrivateKeyPath =
  option str $
    mconcat
      [ long "private-key-path"
      , short 'k'
      , help "Path to the private key"
      ]

getCLArgs :: IO CLArgs
getCLArgs = execParser $ info (parseOptions <**> helper) fullDesc

buildEnv :: IO Env
buildEnv = do
  args <- getCLArgs
  case env args of
    Prod -> do
      viteManifestFile <- LBS.readFile "./client-side/dist/.vite/manifest.json"
      let viteManifest = case eitherDecode viteManifestFile of
            Left errMsg -> error errMsg
            Right ba -> ba
      let homeHtml = case viteHeadHtml "home" ["public"] viteManifest of
            Left errMsg -> error errMsg
            Right html -> html
      let roomHtml = case viteHeadHtml "room" ["public"] viteManifest of
            Left errMsg -> error errMsg
            Right html -> html
      return $ ProdEnv{homeHtml = homeHtml, roomHtml = roomHtml, cert = certificatePath args, key = privateKeyPath args}
    Dev -> return DevEnv{cert = certificatePath args, key = privateKeyPath args}
