module Blindhuhn.Log (
  info,
  debug,
) where

import Agda.TypeChecking.Monad.Debug (MonadDebug, ReportS, VerboseKey, reportS)
import Prelude hiding (log)

info :: (ReportS a, MonadDebug m) => VerboseKey -> a -> m ()
info k = reportS k 1

debug :: (ReportS a, MonadDebug m) => VerboseKey -> a -> m ()
debug k = reportS k 20
