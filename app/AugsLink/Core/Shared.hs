module AugsLink.Core.Shared 
  ( 
    RegistryManage(..) 
  ) where

newtype RegistryManage = RegistryManage {
  selfDestructCallback :: IO ()
}
