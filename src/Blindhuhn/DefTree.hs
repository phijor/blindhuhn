module Blindhuhn.DefTree
  ( DefWith(..)
  , DefTree(..)
  , insert
  ) where

import Agda.Compiler.Backend (Definition, defName)
import Agda.Syntax.Abstract.Name (qnameModule, qnameToMName)
import Data.List (partition)

data DefWith a = DefWith
  { def :: Definition
  , with :: a
  }

newtype DefTree = DefTree [DefWith DefTree]
  deriving (Semigroup, Monoid)

insert :: Definition -> DefTree -> DefTree
insert definition tree@(DefTree definitions) =
  case insertIntoExisting definition tree of
    Just tree' -> tree'
    Nothing -> DefTree $ DefWith definition (DefTree children) : siblings
  where
  newName = defName definition
  newModule = qnameToMName newName

  (children, siblings) = partition isChild definitions
  isChild child = qnameModule (defName $ def child) == newModule

-- Insert below the nearest existing parent.  A 'Maybe' result lets 'insert'
-- distinguish a nested definition from a new root definition.
insertIntoExisting :: Definition -> DefTree -> Maybe DefTree
insertIntoExisting definition (DefTree definitions) = go definitions
  where
  newName = defName definition
  newModule = qnameToMName newName

  go [] = Nothing
  go (first : rest)
    | newModule == qnameToMName (defName $ def first) =
        Just $ DefTree (first : rest)
    | qnameModule newName == qnameToMName (defName $ def first) =
        Just $ DefTree (first { with = insert definition (with first) } : rest)
    | otherwise = case insertIntoExisting definition (with first) of
        Just nested -> Just $ DefTree (first { with = nested } : rest)
        Nothing -> (\(DefTree nested) -> DefTree (first : nested)) <$> go rest
