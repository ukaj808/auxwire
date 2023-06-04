{-# LANGUAGE OverloadedStrings #-}
module AugsLink.Service.Handlers.GetRoom
  ( 
    roomHandler
  ) where

import Servant
import Control.Monad
import Control.Monad.IO.Class
import Text.Blaze.Html5
import Data.Text

import qualified Text.Blaze.Html5            as H
import qualified Text.Blaze.Html5.Attributes as A

import qualified Text.Blaze.Svg11 as S
import qualified Text.Blaze.Svg11.Attributes as SVGA

import AugsLink.Service.API
import AugsLink.Core.API

musicIconSvg :: S.Svg
musicIconSvg = S.docTypeSvg ! SVGA.class_ "centered-icon" ! SVGA.version "1.1" ! SVGA.id_ "Capa_1" ! SVGA.viewbox "0 0 98.121 98.121" ! SVGA.xmlSpace "preserve" $
    S.g $ do
        S.g $ do
            S.path ! SVGA.d "M23.819,14.874h3.273v21.797c0,1.646,1.331,2.973,2.968,2.973h8.102c1.637,0,2.971-1.327,2.971-2.973V14.874h3.276\n\
                        \c0.751,0,1.435-0.438,1.752-1.119c0.313-0.686,0.202-1.485-0.283-2.061L37.109,1.385C36.362,0.504,35.267,0,34.111,0\n\
                        \c-1.151,0-2.247,0.504-2.998,1.385l-8.766,10.309c-0.488,0.576-0.598,1.375-0.28,2.061C22.38,14.436,23.067,14.874,23.819,14.874z"
            S.path ! SVGA.d "M79.199,18.616h-35.5V29.18h32.037v40.025H22.271V29.181h1.828V18.616H18.85c-3.891,0-7.037,2.948-7.037,6.837v47.091\n\
                        \c0,3.905,3.146,7.218,7.037,7.218h24.934v7.794h-9.259c-3.54,0-6.593,2.877-6.593,6.41v4.155h42.246v-4.155\n\
                        \c0-3.533-2.717-6.41-6.249-6.41h-9.591v-7.794h24.859c3.896,0,7.111-3.312,7.111-7.218v-47.09\n\
                        \C86.31,21.565,83.094,18.616,79.199,18.616z"
            S.path ! SVGA.d "M56.623,51.158c-3.314,0-6.006,2.048-6.006,4.574c0,2.522,2.69,4.57,6.006,4.57s6.008-2.048,6.008-4.57\n\
                        \c0-0.099,0-11.625,0-18.042c0-0.97-0.469-1.882-1.258-2.447c-0.787-0.564-1.802-0.714-2.723-0.403l-13.208,4.472\n\
                        \c-1.687,0.572-2.822,2.151-2.834,3.934l-0.043,11.58c-0.366-0.053-0.739-0.084-1.124-0.084c-3.315,0-6.006,2.049-6.006,4.572\n\
                        \s2.69,4.574,6.006,4.574s6.006-2.051,6.006-4.574V48.023c0-0.741,0.473-1.4,1.175-1.64l7.69-2.605\n\
                        \c0.332-0.108,0.695-0.055,0.979,0.147c0.287,0.207,0.455,0.533,0.455,0.884v6.43\n\
                        \C57.379,51.188,57.008,51.158,56.623,51.158z"

listenIconSvg :: S.Svg
listenIconSvg = S.docTypeSvg ! SVGA.class_ "centered-icon" ! SVGA.viewbox "0 0 24 24" $ do
  S.path ! SVGA.d "M13.1807 11.8606C12.7807 11.8606 12.4207 11.6406 12.2507 11.2806L10.8007 8.39058L10.3807 9.17058C10.1507 9.60058 9.6907 9.87058 9.2007 9.87058H8.4707C8.0607 9.87058 7.7207 9.53058 7.7207 9.12058C7.7207 8.71058 8.0607 8.37058 8.4707 8.37058H9.1107L9.9007 6.91058C10.0907 6.57058 10.4707 6.34058 10.8307 6.36058C11.2207 6.36058 11.5707 6.59058 11.7507 6.93058L13.1807 9.79058L13.5207 9.10058C13.7507 8.64058 14.2007 8.36058 14.7207 8.36058H15.5307C15.9407 8.36058 16.2807 8.70058 16.2807 9.11058C16.2807 9.52058 15.9407 9.86058 15.5307 9.86058H14.8207L14.1107 11.2706C13.9307 11.6406 13.5807 11.8606 13.1807 11.8606Z"
  S.path ! SVGA.d "M2.74982 18.6508C2.33982 18.6508 1.99982 18.3108 1.99982 17.9008V12.2008C1.94982 9.49078 2.95982 6.93078 4.83982 5.01078C6.71982 3.10078 9.23982 2.05078 11.9498 2.05078C17.4898 2.05078 21.9998 6.56078 21.9998 12.1008V17.8008C21.9998 18.2108 21.6598 18.5508 21.2498 18.5508C20.8398 18.5508 20.4998 18.2108 20.4998 17.8008V12.1008C20.4998 7.39078 16.6698 3.55078 11.9498 3.55078C9.63982 3.55078 7.49982 4.44078 5.90982 6.06078C4.30982 7.69078 3.45982 9.86078 3.49982 12.1808V17.8908C3.49982 18.3108 3.16982 18.6508 2.74982 18.6508Z"
  S.path ! SVGA.d "M5.94 12.4492H5.81C3.71 12.4492 2 14.1592 2 16.2592V18.1392C2 20.2392 3.71 21.9492 5.81 21.9492H5.94C8.04 21.9492 9.75 20.2392 9.75 18.1392V16.2592C9.75 14.1592 8.04 12.4492 5.94 12.4492Z"
  S.path ! SVGA.d "M18.19 12.4492H18.06C15.96 12.4492 14.25 14.1592 14.25 16.2592V18.1392C14.25 20.2392 15.96 21.9492 18.06 21.9492H18.19C20.29 21.9492 22 20.2392 22 18.1392V16.2592C22 14.1592 20.29 12.4492 18.19 12.4492Z"

renderUser :: RoomUser -> H.Html
renderUser user = 
  let uid = toValue $ userId user
      uname = toMarkup $ userName user
  in
  H.div ! A.id uid ! A.class_ "user-carousel-cell" $ ""


renderOrderSection :: [RoomUser] -> H.Html 
renderOrderSection users = 
  H.section ! A.id "order" ! A.class_ "default-margin" $ do
    H.div ! A.class_"user-carousel" $ do
      forM_ users renderUser 

renderCurrentlyPlayingSection :: H.Html
renderCurrentlyPlayingSection = 
  H.section ! A.id "currently-playing"   ! A.class_ "full-flex centered default-margin secondary-theme overlay-sect overlay" $ do
    H.div ! A.class_ "overlay full-flex centered" $ do
      listenIconSvg

renderDropSection :: H.Html
renderDropSection = 
  H.section ! A.id "drop"      ! A.class_ "full-flex centered default-margin secondary-theme"  $ do
    H.label ! A.for "drop-zone" ! A.class_ "full-flex centered column draggable" $ do
      musicIconSvg
      H.h4 "Upload an audio file or paste a link to get your queue ready in time for your turn!"
      H.input ! A.type_ "file" ! A.id "drop-zone" ! A.accept "audio/*" ! A.style "display:none"

renderRoomPage :: [RoomUser] -> H.Html
renderRoomPage users = H.docTypeHtml $ do
  H.head $ do
    H.title "Room"
    H.meta   ! A.charset "UTF-8"
    H.meta   ! A.name "viewport"  ! A.content "width=device-width, initial-scale=1.0"
    H.script ! A.type_ "module"   ! A.src     "/public/room_bundle.js" $ ""
    H.link   ! A.rel "stylesheet" ! A.href    "https://unpkg.com/flickity@2/dist/flickity.min.css"
    H.link   ! A.rel "stylesheet" ! A.href    "/public/room.css"
    H.link   ! A.rel "icon"       ! A.type_   "image/x-icon"            ! A.href "/public/favicon.ico"
  H.body $ do
    H.main ! A.id "room" ! A.class_ "full-flex column" $ do
      renderOrderSection users
      renderCurrentlyPlayingSection
      renderDropSection
      H.script ! A.src "https://unpkg.com/flickity@2/dist/flickity.pkgd.min.js" $ ""



roomHandler :: Registry IO 
  -> RoomId 
  -> Handler (
       Headers 
       '[
         Header "Cross-Origin-Opener-Policy" Text, 
         Header "Cross-Origin-Embedder-Policy" Text
        ] 
        ServerHtml
      )
roomHandler registry rId = do

  possibleRoom <- liftIO $ getRoom registry rId

  let rm = case possibleRoom of
               Just r -> r
               Nothing -> error "Room does not exist"
  --  Maybe we need to hold lock on room somehow until result returned and confirmed. 
  roomView <- liftIO $ viewRoom rm
  
  return 
    ( 
      addHeader "same-origin"       $
      addHeader "credentialless"      $
      renderRoomPage roomView
    )
