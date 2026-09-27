module Blindhuhn.Backend (backend) where

import Agda.Compiler.Backend
import Agda.Interaction.FindFile (findFile)
import Agda.Interaction.Imports (getNonMainInterface)
import Agda.Interaction.Library (AgdaLibFile (..), LibName, findLib', parseLibName)
import Agda.Interaction.Options (ArgDescr (..), OptDescr (..))
import Agda.Syntax.Common.Pretty (Doc, nest, text, vcat)
import Agda.Utils.IO.UTF8 (writeTextToFile)
import Control.DeepSeq (NFData)
import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
import Data.HashSet (HashSet, empty)
import Data.Maybe (mapMaybe)
import GHC.Generics (Generic)
import System.FilePath ((</>))

import Data.HashSet qualified as HashSet
import Data.Map qualified as Map
import Data.Text qualified as Text

import Blindhuhn.Version (versionString)

import Blindhuhn.Index qualified as Index
import Blindhuhn.Search qualified as Search
import Blindhuhn.VisibilityMap qualified as Vis

backend :: FilePath -> Backend
backend outputDir = Backend backend'
 where
  options :: Options
  options = Options {bhOutputDir = outputDir, bhLibraries = empty, bhSearchEnabled = False}

  backend' :: Backend' Options Env ModuleEnv BhModule BhDef
  backend' =
    Backend'
      { backendName = Text.pack "blindhuhn"
      , backendVersion = Just $ Text.pack versionString
      , options = options
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
  , bhLibraries :: HashSet LibName
  , bhSearchEnabled :: Bool
  }
  deriving (Eq, Generic)

instance NFData Options

blindhuhnCommandLineFlags :: [OptDescr (Flag Options)]
blindhuhnCommandLineFlags =
  [ Option
      []
      ["blindhuhn-index"]
      (ReqArg indexFlag "LIBRARY")
      "index modules from the given library (default: all modules). Can be given multiple times"
  , Option
      []
      ["blindhuhn-search"]
      (NoArg searchFlag)
      "inject a client-side search UI into the generated HTML (requires --html)"
  ]
 where
  indexFlag :: String -> Flag Options
  indexFlag arg o = do
    let libname = parseLibName arg
    return $ o {bhLibraries = HashSet.insert libname $ bhLibraries o}

  searchFlag :: Flag Options
  searchFlag o = return $ o {bhSearchEnabled = True}

data Env = Env
  { bhEnvOptions :: Options
  }

data ModuleEnv = ModuleEnv
  { topLevelName :: TopLevelModuleName
  , visibilities :: Vis.VisibilityMap
  }

data BhModule
  = BhModuleIndexed [Index.Entry]
  | BhModuleSkipped

moduleEntries :: BhModule -> [Index.Entry]
moduleEntries (BhModuleIndexed es) = es
moduleEntries BhModuleSkipped = []

newtype BhDef = BhDef {entry :: Maybe Index.Entry}

bhPreCompile :: Options -> TCM Env
bhPreCompile options = pure $ Env options

-- | Prepare a top-level module for indexing.
--
-- First, this checks whether contents of this module should be
-- indexed at all. If this module does not belong to any of the
-- modules given by @--blindhuhn-index@ (if any were given at
-- all), then the module is skipped.
--
-- If not skipped, compute the visibilities of all definitions
-- contained in this module, even if nested in submodules.
bhPreModule ::
  Env
  -> IsMain
  -> TopLevelModuleName
  -> Maybe FilePath
  -> TCM (Recompile ModuleEnv BhModule)
bhPreModule env _isMain moduleName _interfacePath = do
  shouldIndex <- shouldIndexModule $ bhLibraries $ bhEnvOptions env
  case shouldIndex of
    False -> do
      pure $ Skip BhModuleSkipped
    True -> do
      visibilities <- Vis.fromScopeInfo . iInsideScope <$> getNonMainInterface moduleName Nothing
      pure $ Recompile $ ModuleEnv moduleName visibilities
 where
  -- Does this collection of library files contain one of the given name?
  -- This lookup takes Agda's bespoke version handling into account:
  -- A library file with @name: cubical-0.9@ is considered to have name
  -- @cubical@.
  hasLibByName :: [AgdaLibFile] -> LibName -> Bool
  hasLibByName libs name = not $ null $ findLib' _libName name libs

  -- Do any of the module's owning libraries match any of the
  -- @--blindhuhn-index@ names? If they do, then this module should
  -- be indexed.
  shouldIndexModule :: HashSet LibName -> TCM Bool
  shouldIndexModule libsToIndex
    | null libsToIndex = pure True
    | otherwise = do
        sourcePath <- findFile moduleName >>= srcFilePath
        libFiles <- getAgdaLibFiles sourcePath moduleName
        pure $ any (hasLibByName libFiles) libsToIndex

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
      visibility = Vis.lookup (visibilities modEnv) (defName definition)
      -- Compute the index entry for this definition
      entry = Index.fromDefinition (topLevelName modEnv) visibility definition
    in
      BhDef entry

-- | Collect all index entries from a module
bhPostModule ::
  Env
  -> ModuleEnv
  -> IsMain
  -> TopLevelModuleName
  -> [BhDef]
  -> TCM BhModule
bhPostModule _env _modEnv _isMain _moduleName defs =
  pure $ BhModuleIndexed (mapMaybe entry defs)

bhPostCompile ::
  Env
  -> IsMain
  -> Map.Map TopLevelModuleName BhModule
  -> TCM ()
bhPostCompile env _isMain modules = do
  let opts = bhEnvOptions env
  let outputDir = bhOutputDir opts

  let entries = concatMap moduleEntries $ Map.elems modules
  let index = Index.render entries

  -- Write search index to output directory
  liftIO $ writeTextToFile (outputDir </> "index.json") index

  -- If enabled, inject search UI into existing pages.
  when (bhSearchEnabled opts) $ do
    previouslyInjected <- liftIO $ Search.findPreviousInjections outputDir
    case previouslyInjected of
      [] -> liftIO $ Search.inject outputDir (Search.hashIndex index)
      files -> do
        -- Refuse to modify pages if they already contain injections.
        -- In principle, we could replace the injection but that is
        -- error-prone if we don't properly parse the page HTML.
        let msg = previousInjectionDoc files
        reportSDoc "blindhuhn.search" 1 $ pure msg
        genericDocError msg
 where
  previousInjectionDoc :: [FilePath] -> Doc
  previousInjectionDoc files =
    vcat
      [ text "--blindhuhn-search: refusing to inject the search UI."
      , text "The following HTML files already contain a previous injection:"
      , nest 2 (vcat (map text files))
      , text "Regenerate clean HTML files (e.g. by rerunning with `--html`) before retrying `--blindhuhn-search`."
      ]
