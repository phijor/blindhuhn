{-# LANGUAGE OverloadedStrings #-}

module Unit (tests) where

import Data.Aeson (decode, object, (.=))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertEqual, testCase)

import Data.Text.Lazy.Encoding qualified as TextEncoding

import Blindhuhn.Index (Entry (..), Visibility (..), render)
import Blindhuhn.Search (hasPreviousInjection, injectHead)

tests :: TestTree
tests =
  testGroup
    "Unit"
    [ indexTests
    , searchTests
    ]

indexTests :: TestTree
indexTests =
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

searchTests :: TestTree
searchTests =
  testGroup
    "Search.injectHead"
    [ testCase "inserts the meta/link/script tags before </head>" $ do
        let page = "<!DOCTYPE HTML><html><head><meta charset=\"utf-8\"></head><body></body></html>"
            injected = injectHead "aaa" page
        assertEqual
          "meta/link/script tags inserted before </head>"
          "<!DOCTYPE HTML><html><head><meta charset=\"utf-8\"><!--blindhuhn-search--><meta name=\"blindhuhn-index-hash\" content=\"aaa\"><link rel=\"stylesheet\" href=\"blindhuhn-search.css\"><script type=\"module\" src=\"blindhuhn-search.js\"></script><!--/blindhuhn-search--></head><body></body></html>"
          injected
    , testCase "is a no-op when there is no </head>" $ do
        let page = "<html><body>no head here</body></html>"
        assertEqual "unchanged input without </head>" page (injectHead "aaa" page)
    , testCase "hasPreviousInjection detects an already-injected page" $ do
        let page = "<!DOCTYPE HTML><html><head><meta charset=\"utf-8\"></head><body></body></html>"
            injected = injectHead "aaa" page
        assertBool "a fresh page has no previous injection" (not (hasPreviousInjection page))
        assertBool "an injected page is detected" (hasPreviousInjection injected)
    ]
