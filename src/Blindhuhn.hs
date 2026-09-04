{-# OPTIONS_GHC -Wno-name-shadowing #-}

-- | An Agda backend which combines the standard HTML renderer with a small,
-- machine-readable definition index.
module Blindhuhn
  ( run,
  )
where

import Agda.Main (runAgda)
import Blindhuhn.Backend (backend)
import Control.Applicative ((<|>))
import Data.List (stripPrefix)
import System.Environment (getArgs, withArgs)

-- | Start Agda with the Blindhuhn backend installed.
run :: IO ()
run = do
  args <- getArgs
  -- The HTML backend is a built-in backend and its implementation is not part
  -- of Agda's public Haskell API. Enable it through Agda's normal command
  -- line, then run Blindhuhn alongside it. This also means HTML behavior
  -- stays in lockstep with the Agda version selected by the user.
  withArgs ("--html" : syncHtmlDir args) $ runAgda [backend]
  where
    syncHtmlDir args =
      let withIndexDir = case (blindhuhnHtmlDir args, htmlDir args) of
            (Nothing, Just dir) -> args ++ ["--blindhuhn-html-dir=" ++ dir]
            _ -> args
       in case (htmlDir withIndexDir, blindhuhnHtmlDir withIndexDir) of
            (Nothing, Just dir) -> withIndexDir ++ ["--html-dir=" ++ dir]
            _ -> withIndexDir

    dirOption :: String -> [String] -> Maybe String
    dirOption _opt [] = Nothing
    dirOption opt (opt' : dir : rest)
      | opt == opt' = dirOption opt rest <|> pure dir
      | otherwise = dirOption opt (dir : rest)
    dirOption opt (opt' : rest) =
      case stripPrefix opt opt' of
        Just ('=' : dir) -> dirOption opt rest <|> pure dir
        _ -> dirOption opt rest

    htmlDir = dirOption "--html-dir"
    blindhuhnHtmlDir = dirOption "--blindhuhn-html-dir"
