module Blindhuhn.DefTree (DefWith, DefTree) where

import Agda.Compiler.Backend (Definition)

data DefWith a = DefWith
  { def :: Definition
  , with :: a
  }

newtype DefTree = DefTree [DefWith DefTree]
  deriving (Semigroup, Monoid)

insert :: Definition -> DefTree -> DefTree
insert def (DefTree []) = DefTree [DefWith def mempty]
insert def (DefTree (first : rest)) = _
