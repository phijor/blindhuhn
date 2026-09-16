module Blindhuhn.Backend (backend) where

import Agda.Compiler.Backend
import Agda.Interaction.Imports (getNonMainInterface)
import Agda.Interaction.Options (ArgDescr (..), OptDescr (..))
import Agda.Syntax.Common (NameId)
import Agda.Syntax.Scope.Base (
  NameSpaceId (..),
  Scope,
  ScopeInfo,
  anameName,
  nsNames,
  scopeModules,
  scopeNameSpaces,
 )
import Agda.Utils.IO.UTF8 (writeTextToFile)
import Agda.Utils.Lens ((^.))
import Control.DeepSeq (NFData)
import Control.Monad.IO.Class (liftIO)
import Data.Maybe (mapMaybe)
import GHC.Generics (Generic)
import System.FilePath ((</>))

import Data.List.NonEmpty qualified as NonEmpty
import Data.Map qualified as Map
import Data.Text qualified as Text

import Blindhuhn.Version (versionString)

import Blindhuhn.Index qualified as Index

backend :: FilePath -> Backend
backend outputDir = Backend backend'
 where
  backend' :: Backend' Options Env ModuleEnv BhModule BhDef
  backend' =
    Backend'
      { backendName = Text.pack "blindhuhn"
      , backendVersion = Just $ Text.pack versionString
      , options = Options {bhOutputDir = outputDir, bhOnlyRoot = False}
      , commandLineFlags = blindhuhnCommandLineFlags
      , isEnabled = const True
      , preCompile = bhPreCompile
      , postCompile = bhPostCompile
      , preModule = bhPreModule
      , postModule = bhPostModule
      , compileDef = bhCompileDef
      , scopeCheckingSuffices = False
      , mayEraseType = const $ pure True
      , backendInteractTop = Nothing
      , backendInteractHole = Nothing
      }

data Options = Options
  { bhOutputDir :: FilePath
  , bhOnlyRoot :: Bool
  }
  deriving (Eq, Generic)

instance NFData Options

blindhuhnCommandLineFlags :: [OptDescr (Flag Options)]
blindhuhnCommandLineFlags =
  [ Option
      []
      ["blindhuhn-only-root"]
      (NoArg enableOnlyRoot)
      "restrict the index to the module passed on the command line, dropping modules pulled in via `import`"
  ]
 where
  enableOnlyRoot :: Flag Options
  enableOnlyRoot opts = pure opts {bhOnlyRoot = True}

data Env = Env
  { bhEnvOptions :: Options
  , bhEnvRootModule :: Maybe TopLevelModuleName
  }

data ModuleEnv = ModuleEnv
  { topLevelName :: TopLevelModuleName
  , visibilities :: Map.Map ModuleName (Map.Map NameId Index.Visibility)
  }

newtype BhModule = BhModule {entries :: [Index.Entry]}

newtype BhDef = BhDef {entry :: Maybe Index.Entry}

bhPreCompile :: Options -> TCM Env
bhPreCompile options = do
  rootModule <- currentTopLevelModule
  pure $ Env options rootModule

-- | Compute visibilities of definitions.
--
-- For each top-level module, compute the visibilities of all contained definitions,
-- even if nested in submodules.
bhPreModule ::
  Env
  -> IsMain
  -> TopLevelModuleName
  -> Maybe FilePath
  -> TCM (Recompile ModuleEnv BhModule)
bhPreModule _env _isMain moduleName _interfacePath = do
  visibilities <- visibilityMap . iInsideScope <$> getNonMainInterface moduleName Nothing
  pure $ Recompile $ ModuleEnv moduleName visibilities

-- | Create an index entry for a definition.
--
-- Given a definition, look up its visibility in the definining module
-- using the precomputed visibility map.  From this, create an entry
-- in the index.
bhCompileDef :: Env -> ModuleEnv -> IsMain -> Definition -> TCM BhDef
bhCompileDef _env modEnv _isMain definition =
  pure $
    let
      -- Get visibility of a definition within the current module.
      visibility = lookupVisibility modEnv definition
      -- Compute the index entry for this definition
      entry = Index.fromDefinition (topLevelName modEnv) visibility definition
    in
      BhDef entry

bhPostModule ::
  Env
  -> ModuleEnv
  -> IsMain
  -> TopLevelModuleName
  -> [BhDef]
  -> TCM BhModule
bhPostModule _env _modEnv _isMain _moduleName defs =
  pure $ BhModule {entries = mapMaybe entry defs}

lookupVisibility :: ModuleEnv -> Definition -> Index.Visibility
lookupVisibility modEnv def =
  let qname = defName def
      name = nameId $ qnameName qname
      modName = qnameModule qname
  in Map.findWithDefault Index.Private name $
       Map.findWithDefault Map.empty modName $
         visibilities modEnv

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
visibilityMap :: ScopeInfo -> Map.Map ModuleName (Map.Map NameId Index.Visibility)
visibilityMap scope = Map.map visibilityMapForScope (scope ^. scopeModules)

-- | Compute visibilities for all names in a given scope.
visibilityMapForScope :: Scope -> Map.Map NameId Index.Visibility
visibilityMapForScope scope =
  Map.fromListWith
    mergeVisibility
    [ (nameId (qnameName (anameName abstractName)), visibilityFor namespace)
    | (namespace, nameSpace) <- scopeNameSpaces scope
    , abstractName <- concatMap NonEmpty.toList (Map.elems (nsNames nameSpace))
    ]

visibilityFor :: NameSpaceId -> Index.Visibility
visibilityFor PrivateNS = Index.Private
visibilityFor PublicNS = Index.Public
visibilityFor ImportedNS = Index.Imported

mergeVisibility :: Index.Visibility -> Index.Visibility -> Index.Visibility
mergeVisibility Index.Public _ = Index.Public
mergeVisibility _ Index.Public = Index.Public
mergeVisibility Index.Imported _ = Index.Imported
mergeVisibility _ Index.Imported = Index.Imported
mergeVisibility Index.Private Index.Private = Index.Private

bhPostCompile ::
  Env
  -> IsMain
  -> Map.Map TopLevelModuleName BhModule
  -> TCM ()
bhPostCompile env _isMain modules = do
  let opts = bhEnvOptions env
  modules' <-
    if bhOnlyRoot opts then case bhEnvRootModule env of
      Nothing ->
        genericError
          "blindhuhn: --blindhuhn-only-root was given, but Agda did not report a current top-level module (no input file checked?)"
      Just m -> pure $ Map.filterWithKey (\k _ -> k == m) modules
    else
      pure modules
  let entries' = concatMap entries $ Map.elems modules'
  let output = bhOutputDir opts </> "index.json"
  liftIO $ writeTextToFile output (Index.render entries')
