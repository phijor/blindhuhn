module Blindhuhn.Version (versionString, version) where

import Data.Version (showVersion)
import Paths_Blindhuhn (version)

versionString :: String
versionString = showVersion version
