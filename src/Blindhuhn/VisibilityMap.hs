module Blindhuhn.VisibilityMap (VisibilityMap, lookup, fromScopeInfo) where

import Agda.Syntax.Abstract (ModuleName, QName (qnameModule))
import Agda.Syntax.Common (NameId)
import Agda.Syntax.Scope.Base (
  NameSpace (..),
  NameSpaceId (..),
  Scope (..),
  ScopeInfo,
  scopeModules,
 )
import Agda.Utils.Lens ((^.))
import Prelude hiding (lookup)

import Data.List.NonEmpty qualified as NonEmpty
import Data.Map qualified as Map

import Blindhuhn.Name (HasNameId (..))

import Blindhuhn.Index qualified as Index

type NameMap = Map.Map NameId Index.Visibility

newtype VisibilityMap = VisibilityMap (Map.Map ModuleName NameMap)

-- | For all modules in a scope, compute a map of names they contain to their visibilities in this scope.
--
-- If this module is in scope:
--
-- > module Foo where
-- >  private
-- >    Bar : ℕ
-- >    Bar = 0
-- >
-- >  Baz : ℕ
-- >  Baz = 1
--
-- then @Foo@ maps to @{ Bar = Private, Baz = Public }@.
fromScopeInfo :: ScopeInfo -> VisibilityMap
fromScopeInfo s = VisibilityMap $ Map.map nameMapFromScope $ s ^. scopeModules
 where
  nsIdToVis :: NameSpaceId -> Index.Visibility
  nsIdToVis PrivateNS = Index.Private
  nsIdToVis PublicNS = Index.Public
  nsIdToVis ImportedNS = Index.Imported

  --  Compute visibility for all names in a given scope.
  --
  --  A name's @NameId@ could in principle appear under more than one @NameSpaceId@
  --  (a scope has all three name spaces at once), which is why this merges with
  --  @max@ instead of using a plain @Map.fromList@.  In practice, this does not
  --  seem to happen.  In any case, using @max@ makes the insertion order deterministic
  --  and independent of the order in which names happen to appear.
  nameMapFromScope :: Scope -> NameMap
  nameMapFromScope scope = Map.fromListWith (max @Index.Visibility) $ do
    (nsId, ns) <- scopeNameSpaces scope
    abstractName <- concatMap NonEmpty.toList $ Map.elems $ nsNames ns
    pure $ (nameId abstractName, nsIdToVis nsId)

lookup :: VisibilityMap -> QName -> Index.Visibility
lookup (VisibilityMap vis) qname =
  let
    nameMap = Map.findWithDefault Map.empty (qnameModule qname) vis
  in
    Map.findWithDefault Index.Private (nameId qname) nameMap
