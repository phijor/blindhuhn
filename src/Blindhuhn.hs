{-# OPTIONS_GHC -Wno-name-shadowing #-}

-- | An Agda backend which combines the standard HTML renderer with a small,
-- machine-readable definition index.
module Blindhuhn
  ( run,
  )
where

import Agda.Compiler.Backend (Backend (..), Backend' (isEnabled))
import Agda.Interaction.Highlighting.HTML (htmlBackend)
import Agda.Main (runAgda')
import Blindhuhn.Backend (backend)
import Control.Applicative ((<|>))
import Data.List (stripPrefix)
import Data.Maybe (fromMaybe)
import System.Environment (getArgs)

-- | Start Agda with the Blindhuhn backend installed.
run :: IO ()
run = do
  args <- getArgs
  runAgda' [alwaysEnabled htmlBackend, backend (htmlDir args)]
  where
    alwaysEnabled (Backend backend') =
      Backend backend' {isEnabled = const True}

    htmlDir :: [String] -> String
    htmlDir args = fromMaybe "html" $ go args
      where
        -- | Parse arguments of the form `--html-dir <DIR>` or `--html-dir=<DIR>`.
        go :: [String] -> Maybe String
        go [] = Nothing
        go ("--html-dir" : dir : rest) = go rest <|> pure dir
        go (opt : rest) =
          case stripPrefix "--html-dir=" opt of
            Just dir@(_ : _) -> go rest <|> pure dir
            _ -> go rest
