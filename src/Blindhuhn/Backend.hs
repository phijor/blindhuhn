module Blindhuhn.Backend (backend) where

import Agda.Compiler.Backend
import Agda.Compiler.Common (curIF)
import Agda.Syntax.Common (NameId)
import Agda.Syntax.Scope.Base
  ( NameSpaceId(..)
  , Scope
  , ScopeInfo
  , anameName
  , nsNames
  , scopeModules
  , scopeNameSpaces
  )
import Agda.Utils.IO.UTF8 (writeTextToFile)
import Agda.Utils.Lens ((^.))
import Blindhuhn.Index qualified as Index
import Blindhuhn.Version (versionString)
import Control.DeepSeq (NFData)
import Control.Monad.IO.Class (liftIO)
import Data.List.NonEmpty qualified as NonEmpty
import Data.Map qualified as Map
import Data.Maybe (mapMaybe)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import System.FilePath ((</>))

backend :: FilePath -> Backend
backend outputDir = Backend (backend' {options = initialBhOptions {bhOutputDir = outputDir}})

newtype BhOptions = BhOptions
  { bhOutputDir :: FilePath
  }
  deriving (Eq, Generic)

instance NFData BhOptions

newtype BhEnv = BhEnv
  { bhEnvOptions :: BhOptions
  }

newtype BhModuleEnv = BhModuleEnv
  (TopLevelModuleName, Map.Map ModuleName (Map.Map NameId Index.Visibility))

newtype BhModule = BhModule [Index.Entry]

newtype BhDef = BhDef (Maybe Index.Entry)

initialBhOptions :: BhOptions
initialBhOptions =
  BhOptions
    { bhOutputDir = "html"
    }

backend' :: Backend' BhOptions BhEnv BhModuleEnv BhModule BhDef
backend' =
  Backend'
    { backendName = Text.pack "blindhuhn",
      backendVersion = Just $ Text.pack versionString,
      options = initialBhOptions,
      commandLineFlags = [],
      isEnabled = const True,
      preCompile = bhPreCompile,
      postCompile = bhPostCompile,
      preModule = bhPreModule,
      postModule = bhPostModule,
      compileDef = bhCompileDef,
      scopeCheckingSuffices = False,
      mayEraseType = const $ pure True,
      backendInteractTop = Nothing,
      backendInteractHole = Nothing
    }

bhPreCompile :: BhOptions -> TCM BhEnv
bhPreCompile options = pure $ BhEnv options

bhPreModule ::
  BhEnv ->
  IsMain ->
  TopLevelModuleName ->
  Maybe FilePath ->
  TCM (Recompile BhModuleEnv BhModule)
bhPreModule _env _isMain moduleName _interfacePath =
  Recompile . BhModuleEnv . (moduleName,) . visibilityMap . iInsideScope <$> curIF

bhCompileDef :: BhEnv -> BhModuleEnv -> IsMain -> Definition -> TCM BhDef
bhCompileDef _env modEnv _isMain definition = do
  -- The numeric anchor is the source position used by Agda's HTML backend.
  -- Definitions without a source range (for example compiler primitives) do
  -- not have a useful page location and are omitted from the index.
  pure $ BhDef $ Index.fromDefinition (bhModEnvName modEnv) (bhVisibility modEnv definition) definition

bhPostModule ::
  BhEnv ->
  BhModuleEnv ->
  IsMain ->
  TopLevelModuleName ->
  [BhDef] ->
  TCM BhModule
bhPostModule _env _modEnv _isMain _moduleName defs =
  pure $ BhModule $ mapMaybe entryOf defs
  where
    entryOf (BhDef entry) = entry

bhModEnvName :: BhModuleEnv -> TopLevelModuleName
bhModEnvName (BhModuleEnv (moduleName, _)) = moduleName

bhVisibility :: BhModuleEnv -> Definition -> Index.Visibility
bhVisibility (BhModuleEnv (_, visibilityByModule)) definition =
  Map.findWithDefault Index.Private (nameId (qnameName definitionName)) definitions
  where
    definitionName = defName definition
    definitions = Map.findWithDefault Map.empty (qnameModule definitionName) visibilityByModule

visibilityMap :: ScopeInfo -> Map.Map ModuleName (Map.Map NameId Index.Visibility)
visibilityMap scope = Map.map visibilityMapForScope (scope ^. scopeModules)

visibilityMapForScope :: Scope -> Map.Map NameId Index.Visibility
visibilityMapForScope scope =
  Map.fromListWith mergeVisibility
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
  BhEnv ->
  IsMain ->
  Map.Map TopLevelModuleName BhModule ->
  TCM ()
bhPostCompile env _isMain modules = do
  let entries = concatMap entriesOf $ Map.elems modules
  let output = bhOutputDir (bhEnvOptions env) </> "index.json"
  liftIO $ writeTextToFile output (Index.render entries)
  where
    entriesOf (BhModule entries) = entries
