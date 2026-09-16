module Main (main) where

import Test.Tasty (defaultMain, testGroup)

import Golden qualified
import Unit qualified

main :: IO ()
main = do
  golden <- Golden.tests
  defaultMain $ testGroup "Blindhuhn" [Unit.tests, golden]
