{-# LANGUAGE OverloadedStrings #-}

module Blindhuhn.Index
  ( Entry(..)
  , fromDefinition
  , render
  ) where

import Agda.Compiler.Backend
  ( Definition
  , defName
  , nameBindingSite
  , qnameName
  , qnameToConcrete
  )
import Agda.Syntax.Position (posCol, posLine, posPos, rStart)
import Agda.Syntax.TopLevelModuleName (TopLevelModuleName)
import Agda.Utils.Pretty (prettyShow)

import Control.DeepSeq (NFData)
import Data.Aeson (ToJSON(..), encode, object, (.=))
import Data.List (nubBy, sortOn)
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy.Encoding as TextEncoding
import GHC.Generics (Generic)
import Network.URI.Encode qualified as URI

-- | A definition and its location in generated HTML.
--
-- 'position' is Agda's one-based character offset, the same value used by the
-- standard HTML backend for its numeric anchors. 'line' and 'column' are
-- included for consumers that want to display a source location without
-- parsing the source file.
data Entry = Entry
  { indexName :: String
  , indexModule :: String
  , indexPath :: FilePath
  , indexPosition :: Int
  , indexLine :: Int
  , indexColumn :: Int
  }
  deriving (Eq, Ord, Show, Generic)

instance NFData Entry

instance ToJSON Entry where
  toJSON entry = object
    [ "name" .= indexName entry
    , "module" .= indexModule entry
    , "path" .= indexPath entry
    , "position" .= indexPosition entry
    , "line" .= indexLine entry
    , "column" .= indexColumn entry
    ]

-- | Turn a compiled definition into an entry.
fromDefinition :: TopLevelModuleName -> Definition -> Maybe Entry
fromDefinition moduleName definition = do
  start <- rStart $ nameBindingSite $ qnameName $ defName definition
  let position = fromIntegral $ posPos start
      moduleText = prettyShow moduleName
  pure Entry
    { indexName = prettyShow $ qnameToConcrete $ defName definition
    , indexModule = moduleText
    , indexPath = URI.encode (moduleText ++ ".html") ++ "#" ++ show position
    , indexPosition = position
    , indexLine = fromIntegral $ posLine start
    , indexColumn = fromIntegral $ posCol start
    }

-- | Render the definition index as deterministic UTF-8 JSON.
render :: [Entry] -> Text
render entries = TextEncoding.decodeUtf8 $ encode $ object
  [ "definitions" .= ordered
  ]
  where
  ordered = sortOn id . nubBy sameLocation $ entries
  sameLocation a b =
    (indexName a, indexPath a, indexPosition a) ==
    (indexName b, indexPath b, indexPosition b)
