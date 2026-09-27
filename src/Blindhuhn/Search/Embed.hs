-- | Locate and embed vendored search assets.
module Blindhuhn.Search.Embed (
  embedVendoredAsset,
)
where

import Data.FileEmbed (embedFile)
import Language.Haskell.TH (Exp, Q)
import Language.Haskell.TH.Syntax (runIO)
import System.Environment (lookupEnv)
import System.FilePath ((</>))

vendoredAssetsDirEnvVar :: String
vendoredAssetsDirEnvVar = "BLINDHUHN_VENDORED_ASSETS_DIR"

-- | Template Haskell splice for embedding vendored assets.
--
-- @embedVendoredAsset path@ looks up @$BLINDHUHN_VENDORED_ASSETS_DIR/path@
-- and embeds the file it finds there.
--
-- Fails if @$BLINDHUHN_VENDORED_ASSETS_DIR$@ is unset.
embedVendoredAsset :: FilePath -> Q Exp
embedVendoredAsset relPath = do
  found <- runIO $ lookupEnv vendoredAssetsDirEnvVar
  dir <- case found of
    Just dir -> pure dir
    Nothing ->
      fail $
        concat
          [ vendoredAssetsDirEnvVar
          , " is not set."
          , " The Nix flake sets this automatically (see nix/vendored-assets.nix)."
          , " For a plain `cabal build`, set it by hand."
          ]
  embedFile (dir </> relPath)
