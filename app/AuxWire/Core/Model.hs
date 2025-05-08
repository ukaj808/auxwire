module AuxWire.Core.Model where

import Data.UUID

import Data.HashMap.Lazy qualified as HM
import Data.Map qualified as M

import AuxWire.Core.API
import Commons.State
import Data.Text

type InternalId = Int

type instance Connection IO = Text
type instance UserId IO = Text
