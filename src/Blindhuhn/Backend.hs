module Blindhuhn.Backend (backend) where

import Agda.Compiler.Backend
import Agda.Interaction.Options (ArgDescr (..), OptDescr (..))
import Agda.Syntax.TopLevelModuleName (TopLevelModuleName)
import Agda.Utils.IO.UTF8 (writeTextToFile)
import Blindhuhn.Index qualified as Index
import Blindhuhn.Version (versionString)
import Control.DeepSeq (NFData)
import Control.Monad.IO.Class (liftIO)
import Data.Map qualified as Map
import Data.Maybe (mapMaybe)
import GHC.Generics (Generic)
import System.FilePath ((</>))

backend :: Backend
backend = Backend backend'

-- | Options intentionally use a backend-specific prefix. Agda also installs
-- the built-in HTML backend, whose @--html-dir@ option would otherwise be
-- ambiguous when both backends are present.
newtype BhOptions = BhOptions
  { bhOutputDir :: FilePath
  }
  deriving (Eq, Generic)

instance NFData BhOptions

newtype BhEnv = BhEnv
  { bhEnvOptions :: BhOptions
  }

newtype BhModuleEnv = BhModuleEnv TopLevelModuleName

newtype BhModule = BhModule [Index.Entry]

newtype BhDef = BhDef (Maybe Index.Entry)

initialBhOptions :: BhOptions
initialBhOptions =
  BhOptions
    { bhOutputDir = "html"
    }

bhFlags :: [OptDescr (Flag BhOptions)]
bhFlags =
  [ Option
      []
      ["blindhuhn-html-dir"]
      (ReqArg bhOutputDirFlag "DIR")
      "directory in which Blindhuhn HTML and index files are placed (default: html)"
  ]

bhOutputDirFlag :: FilePath -> Flag BhOptions
bhOutputDirFlag dir options = pure options {bhOutputDir = dir}

backend' :: Backend' BhOptions BhEnv BhModuleEnv BhModule BhDef
backend' =
  Backend'
    { backendName = "blindhuhn",
      backendVersion = Just versionString,
      options = initialBhOptions,
      commandLineFlags = bhFlags,
      isEnabled = const True,
      preCompile = bhPreCompile,
      postCompile = bhPostCompile,
      preModule = bhPreModule,
      postModule = bhPostModule,
      compileDef = bhCompileDef,
      scopeCheckingSuffices = False,
      mayEraseType = const $ pure True
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
  pure $ Recompile $ BhModuleEnv moduleName

bhCompileDef :: BhEnv -> BhModuleEnv -> IsMain -> Definition -> TCM BhDef
bhCompileDef _env modEnv _isMain definition = do
  -- The numeric anchor is the source position used by Agda's HTML backend.
  -- Definitions without a source range (for example compiler primitives) do
  -- not have a useful page location and are omitted from the index.
  pure $ BhDef $ Index.fromDefinition (bhModEnvName modEnv) definition

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
bhModEnvName (BhModuleEnv moduleName) = moduleName

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
