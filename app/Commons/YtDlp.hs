{-# LANGUAGE OverloadedStrings #-}

module Commons.YtDlp (
  ytdlpDownload,
  YtdlpOutput (..),
  ytdlpValid,
  ytdlpTemplatePath,
) where

import Control.Exception
import Data.Aeson
import System.Process

import Data.ByteString.Lazy.Char8 qualified as BLC
import Data.Text qualified as T

type YtdlpExecutable = FilePath
type URL = String
data Simulate = Simulate | Download FilePath

-- Parameters: Path to the YtdlpExecutable
--             URL to the video
-- Result:     True if yt-dlp can download the video
--             False if yt-dlp cannot download the video in which case it will return an exit code
ytdlpValid :: YtdlpExecutable -> URL -> IO String
ytdlpValid exec url =
  catch
    ( do
        (_, result) <- ytdlp exec [skipDownloadArg] url Simulate
        return $ ytdlpTitle result
    )
    ( \(e :: IOError) -> do
        print $ show e
        return ""
    )

-- Parameters: Path to the YtdlpExecutable
--             Directory to save the video (should be a directory; not a file)
--             URL to the video
-- Result:     (Path to the downloaded video, Video metadata)
--
ytdlpDownload :: YtdlpExecutable -> FilePath -> URL -> IO (FilePath, YtdlpOutput)
ytdlpDownload exec out url = do
  ytdlOutput <- ytdlp exec (forceOverwriteArg : ytdlpOutputArg out) url (Download out)
  case ytdlOutput of
    (Just path, ytdlpOut) -> return (path, ytdlpOut)
    (Nothing, _) -> error "ytdlpDownload: ytdlp returned Nothing"

-- Parameters: Path to the YtdlpExecutable Extra arguments to pass to yt-dlp, ontop of the default arguments (see below*)
--             URL to the video
--             Simulate the download (True) or actually download the video (False)
-- Result:     (Po*ssibly a file path, depending on the simulate argument, Video metadata)
--
ytdlp :: YtdlpExecutable -> [String] -> URL -> Simulate -> IO (Maybe FilePath, YtdlpOutput)
ytdlp exec args url sim = do
  let noSimArg' = case sim of
        Simulate -> []
        Download _ -> [noSimArg]
  jsonOutput <- readProcess exec (args ++ noSimArg' ++ [fullJsonDumpArg, url]) ""
  let result = eitherDecode (BLC.pack jsonOutput) :: Either String YtdlpOutput
  case result of
    Left err -> error err
    Right ytdlpOut -> do
      case sim of
        Simulate -> return (Nothing, ytdlpOut)
        Download out -> do
          return (Just (ytdlpTemplatePathReplaced out ytdlpOut), ytdlpOut)

-- Parameters: Directory where you want the file to be downloaded to
--
-- Result:     An array containing the output flag and its value e.g. ["-o", "./someDir/"]
--
ytdlpOutputArg :: FilePath -> [String]
ytdlpOutputArg = outputTemplateArg . ytdlpTemplatePath

-- Parameters: Directory where you want the file file to be downloaded to
--             Download metadata which will be used to replace the values in the template string

-- Result:     The file path where the video was downloaded to
--
ytdlpTemplatePathReplaced :: FilePath -> YtdlpOutput -> FilePath
ytdlpTemplatePathReplaced dir ytdlpOut = T.unpack $ T.replace "%(ext)s" (T.pack $ ytdlpExt ytdlpOut) $ T.replace "%(title)s" (T.pack $ ytdlpTitle ytdlpOut) (T.pack $ ytdlpTemplatePath dir)

-- Parameters: Directory where you want the file to be downloaded to
--
-- Result:     A template file path used for the ytdlp executable e,g, "./somedir/%(title)s.%(ext)s"
ytdlpTemplatePath :: FilePath -> FilePath
ytdlpTemplatePath [] = ytdlTemplateStr
ytdlpTemplatePath dir
  | last dir == '/' = dir ++ ytdlTemplateStr
  | otherwise = dir ++ '/' : ytdlTemplateStr

-- Result:     A standard ytdlp template used for the output file name
ytdlTemplateStr :: String
ytdlTemplateStr = "%(title)s.%(ext)s"

-- Result:     A argument to the yt-dlp executable, skips prompting for user input if the output file already exists
forceOverwriteArg :: String
forceOverwriteArg = "--force-overwrites"

-- Result:     A argument to the yt-dlp executable; there are some arguments that imply simulation. Adding this ensures the file will be downloaded in those cases.
noSimArg :: String
noSimArg = "--no-simulate"

-- Result:     A argument to the yt-dlp executable, which prints a json output instead of the standard stdout lines of yt-dlp

-- * Warning:   Adding this argument tells the yt-dlp exec that it should SIMULATE a download. Provide the --no-simulate arg in

--             coonjuction with this arg if you want json output AND the downloaded file.
fullJsonDumpArg :: String
fullJsonDumpArg = "-J"

-- Result:    A argument to the yt-dlp executable, which tells yt-dlp to skip actually downloading the file
--
skipDownloadArg :: String
skipDownloadArg = "--skip-download"

-- Parameters: Template path including the directory you want to output to, e.g. "./somedir/%(title)s.%(ext)s"
--
-- Result:     An array containing a pair; the argument key for the outputt template -o and the template path e.g. ["-o", "./somedir/%(title)s.%(ext)s"]
outputTemplateArg :: FilePath -> [String]
outputTemplateArg path = ["-o", path]

data YtdlpOutput = YtdlpOutput
  { ytdlpId :: String
  , ytdlpTitle :: String
  , ytdlpThumbnail :: String
  , ytdlpDescription :: String
  , ytdlpUploader :: String
  , ytdlpChannel :: String
  , ytdlpFullTitle :: String
  , ytdlpExt :: String
  , ytdlpDuration :: Int
  }
  deriving (Show)

instance FromJSON YtdlpOutput where
  parseJSON = withObject "YtdlpOutput" $ \o -> do
    ytdlpId <- o .: "id"
    ytdlpTitle <- o .: "title"
    ytdlpThumbnail <- o .: "thumbnail"
    ytdlpDescription <- o .: "description"
    ytdlpUploader <- o .: "uploader"
    ytdlpDuration <- o .: "duration"
    ytdlpChannel <- o .: "channel"
    ytdlpFullTitle <- o .: "fulltitle"
    ytdlpExt <- o .: "ext"
    return
      YtdlpOutput
        { ytdlpId = ytdlpId
        , ytdlpTitle = ytdlpTitle
        , ytdlpThumbnail = ytdlpThumbnail
        , ytdlpDescription = ytdlpDescription
        , ytdlpUploader = ytdlpUploader
        , ytdlpDuration = ytdlpDuration
        , ytdlpChannel = ytdlpChannel
        , ytdlpFullTitle = ytdlpFullTitle
        , ytdlpExt = ytdlpExt
        }
