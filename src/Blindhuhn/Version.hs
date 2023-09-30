{-# LANGUAGE TemplateHaskell #-}

module Blindhuhn.Version (versionString) where

import Data.Version.Package (packageVersionStringTH)

versionString :: String
versionString = $$(packageVersionStringTH "../../Blindhuhn.cabal")
