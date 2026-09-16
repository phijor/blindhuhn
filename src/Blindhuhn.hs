{-# OPTIONS_GHC -Wno-name-shadowing #-}

-- | An Agda backend which combines the standard HTML renderer with a small,
-- machine-readable definition index.
module Blindhuhn (
  run,
)
where

import Agda.Interaction.Highlighting.HTML (htmlBackend)
import Agda.Main (runAgda')
import Control.Applicative ((<|>))
import Data.List (stripPrefix)
import Data.Maybe (fromMaybe)
import System.Environment (getArgs)

import Agda.Compiler.Backend qualified as B

import Blindhuhn.Backend (backend)

-- | Start Agda with the Blindhuhn backend installed.
run :: IO ()
run = do
  args <- getArgs
  runAgda' [alwaysEnabled htmlBackend, backend (htmlDir args)]
 where
  alwaysEnabled :: B.Backend -> B.Backend
  alwaysEnabled (B.Backend backend') =
    B.Backend backend' {B.isEnabled = const True}

  htmlDir :: [String] -> String
  htmlDir args = fromMaybe "html" $ go args
   where
    -- Parse arguments of the form `--html-dir <DIR>` or `--html-dir=<DIR>`.
    -- Later arguments take priority over earlier ones.
    go :: [String] -> Maybe String
    go [] = Nothing
    go ("--html-dir" : dir : rest) = go rest <|> pure dir
    go (opt : rest) =
      case stripPrefix "--html-dir=" opt of
        Just dir@(_ : _) -> go rest <|> pure dir
        _ -> go rest
