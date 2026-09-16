{-# LANGUAGE OverloadedStrings #-}

module Unit (tests) where

import Data.Aeson (decode, object, (.=))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertEqual, testCase)

import Data.Text.Lazy.Encoding qualified as TextEncoding

import Blindhuhn.Index (Entry (..), Visibility (..), render)

tests :: TestTree
tests =
  testGroup
    "Index.render"
    [ testCase "sorts, deduplicates by location, and escapes JSON" $ do
        let entries =
              [ Entry "zeta" "Example" "Example.html#20" 20 2 1 Public
              , Entry "alpha\"quoted" "Example" "Example.html#10" 10 1 1 Private
              , Entry "alpha\"quoted" "Example" "Example.html#10" 10 1 1 Private
              , Entry "imported" "Example" "Example.html#15" 15 1 6 Imported
              ]
            rendered = TextEncoding.encodeUtf8 $ render entries
            expected =
              object
                [ "definitions"
                    .= [ object
                           [ "name" .= ("alpha\"quoted" :: String)
                           , "module" .= ("Example" :: String)
                           , "path" .= ("Example.html#10" :: String)
                           , "position" .= (10 :: Int)
                           , "line" .= (1 :: Int)
                           , "column" .= (1 :: Int)
                           , "visibility" .= ("private" :: String)
                           ]
                       , object
                           [ "name" .= ("imported" :: String)
                           , "module" .= ("Example" :: String)
                           , "path" .= ("Example.html#15" :: String)
                           , "position" .= (15 :: Int)
                           , "line" .= (1 :: Int)
                           , "column" .= (6 :: Int)
                           , "visibility" .= ("imported" :: String)
                           ]
                       , object
                           [ "name" .= ("zeta" :: String)
                           , "module" .= ("Example" :: String)
                           , "path" .= ("Example.html#20" :: String)
                           , "position" .= (20 :: Int)
                           , "line" .= (2 :: Int)
                           , "column" .= (1 :: Int)
                           , "visibility" .= ("public" :: String)
                           ]
                       ]
                ]
        assertEqual "rendered JSON matches expected" (Just expected) (decode rendered)
    ]
