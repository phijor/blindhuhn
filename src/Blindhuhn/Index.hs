{-# LANGUAGE OverloadedStrings #-}

module Blindhuhn.Index (
  Entry (..),
  Visibility (..),
  fromDefinition,
  render,
)
where

import Agda.Compiler.Backend (Definition, defName, nameBindingSite)
import Agda.Syntax.Abstract.Name (ModuleName, isNoName, mnameFromList, mnameToList, qnameModule, qnameName)
import Agda.Syntax.Common.Pretty (prettyShow)
import Agda.Syntax.Position (posCol, posLine, posPos, rStart)
import Agda.Syntax.TopLevelModuleName (TopLevelModuleName)
import Control.DeepSeq (NFData)
import Control.Monad (guard)
import Data.Aeson (ToJSON (..), encode, object, (.=))
import Data.List (nubBy, sort)
import Data.Text.Lazy (Text)
import GHC.Generics (Generic)

import Data.Text.Lazy.Encoding qualified as TextEncoding
import Network.URI.Encode qualified as URI

-- | Visibility of a definition in its defining module's scope.
data Visibility
  = Private
  | Imported
  | Public
  deriving (Eq, Ord, Show, Generic)

instance NFData Visibility

instance ToJSON Visibility where
  toJSON Private = "private"
  toJSON Public = "public"
  toJSON Imported = "imported"

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
  , indexVisibility :: Visibility
  }
  deriving (Eq, Ord, Show, Generic)

instance NFData Entry

instance ToJSON Entry where
  toJSON entry =
    object
      [ "name" .= indexName entry
      , "module" .= indexModule entry
      , "path" .= indexPath entry
      , "position" .= indexPosition entry
      , "line" .= indexLine entry
      , "column" .= indexColumn entry
      , "visibility" .= indexVisibility entry
      ]

-- | Turn a compiled definition into an entry.
--
-- The numeric anchor is the source position used by Agda's HTML backend.
-- Definitions without a source range (for example compiler primitives) do
-- not have a useful page location and are omitted from the index.
fromDefinition :: TopLevelModuleName -> Visibility -> Definition -> Maybe Entry
fromDefinition moduleName visibility definition = do
  start <- rStart $ nameBindingSite $ qnameName $ defName definition
  let position = fromIntegral $ posPos start
      pageModuleText = prettyShow moduleName
      definitionName = defName definition
      name = prettyShow $ qnameName definitionName
      moduleText = prettyShow $ dropAnonModules $ qnameModule definitionName
  -- Do not index compiler-generated definitions.
  -- They can never be named from an Agda program and are useless search results.
  guard (not (isGeneratedName name))
  pure
    Entry
      { indexName = name
      , indexModule = moduleText
      , indexPath = URI.encode (pageModuleText ++ ".html") ++ "#" ++ show position
      , indexPosition = position
      , indexLine = fromIntegral $ posLine start
      , indexColumn = fromIntegral $ posCol start
      , indexVisibility = visibility
      }

-- | Compiler-generated names (extended lambdas, absurd lambdas, ...) start
-- with a dot, which cannot appear in a source-level Agda identifier.
isGeneratedName :: String -> Bool
isGeneratedName ('.' : _) = True
isGeneratedName _ = False

-- | Drop @_@ components from module paths.
--
-- An anonymous module (`module _ where`) contributes a "_" component
-- to the qualified name of everything defined inside it, but any such
-- definition is reachable without ever naming that module.
dropAnonModules :: ModuleName -> ModuleName
dropAnonModules = mnameFromList . filter (not . isNoName) . mnameToList

-- | Render the definition index as deterministic UTF-8 JSON.
render :: [Entry] -> Text
render entries =
  TextEncoding.decodeUtf8 $
    encode $
      object
        [ "definitions" .= ordered
        ]
 where
  ordered = sort . nubBy sameLocation $ entries
  sameLocation a b =
    (indexName a, indexPath a, indexPosition a)
      == (indexName b, indexPath b, indexPosition b)
