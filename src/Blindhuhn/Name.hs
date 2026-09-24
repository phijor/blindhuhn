module Blindhuhn.Name (HasNameId (..)) where

import Agda.Syntax.Abstract (Name, QName (qnameName))
import Agda.Syntax.Common (NameId)
import Agda.Syntax.Scope.Base (AbstractName (anameName))

import Agda.Syntax.Abstract qualified as AbsSyn

class HasNameId a where
  nameId :: a -> NameId

instance HasNameId Name where
  nameId = AbsSyn.nameId

instance HasNameId QName where
  nameId = nameId . qnameName

instance HasNameId AbstractName where
  nameId = nameId . anameName
