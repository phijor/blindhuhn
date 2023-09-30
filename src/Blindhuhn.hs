{-# OPTIONS_GHC -Wno-name-shadowing #-}

module Blindhuhn (run) where

import Blindhuhn.Version (versionString)

import Control.DeepSeq (NFData)
import Control.Monad (forM_)
import GHC.Generics (Generic)

import Agda.Compiler.Backend
import Agda.Interaction.Options (OptDescr)
import Agda.Main (runAgda)
import Agda.Syntax.Abstract.Pretty (prettyATop)
import Agda.Syntax.Internal as I
import Agda.Syntax.TopLevelModuleName (TopLevelModuleName)
import Agda.Syntax.Translation.InternalToAbstract (MonadReify, Reify (reify))
import Agda.TypeChecking.Pretty

run :: IO ()
run = runAgda [backend]

backend :: Backend
backend = Backend backend'

backend' :: Backend' BhOptions BhEnv BhModuleEnv BhModule Definition
backend' =
  Backend'
    { scopeCheckingSuffices = False
    , preModule = \_env _isMain _module _interface -> return $ Recompile BhModEnv
    , preCompile = \_env -> return BhEnv
    , postModule = bhPostModule
    , postCompile = \_env _isMain _modules -> return ()
    , options = BhOptions
    , mayEraseType = const $ return True
    , isEnabled = const True
    , compileDef = \_env _modEnv _isMain definition -> return definition
    , commandLineFlags = bhFlags
    , backendVersion = Just versionString
    , backendName = "blindhuhn"
    }

data BhEnv = BhEnv
data BhModuleEnv = BhModEnv
data BhModule = BhModule

data BhOptions = BhOptions
  deriving (Eq, Generic)
instance NFData BhOptions

bhFlags :: [OptDescr (Flag BhOptions)]
bhFlags = []

isTopLevelDef :: Definition -> Bool
isTopLevelDef _def = True

-- let moduleName = qnameModule $ defName def
-- in isNoName $ qnameName $ defName def
-- moduleName == noModuleName

prettyType :: (MonadReify m, MonadAbsToCon m) => I.Type -> m Doc
prettyType ty = do
  abstractType <- reify ty
  prettyATop abstractType

bhPostModule :: BhEnv -> BhModuleEnv -> IsMain -> TopLevelModuleName -> [Definition] -> TCM BhModule
bhPostModule _env _modEnv _isMain mod defs = do
  reportSDoc "blindhuhn" 5 $ text "postModule: " <> prettyTCM mod
  forM_ (filter isTopLevelDef defs) $ \def -> do
    let qname = defName def
        -- qmod = qnameModule qname
        -- qnameId = showQNameId qname
        qtype = defType def
    reportSDoc "blindhuhn" 5 $
      -- text "postModule: definition: " <+> prettyTCM qnameId <+> prettyTCM qname <+> prettyTCM qmod
      -- <+> prettyTCM (getRange $ theDef def)
      text "postModule: definition: " <+> prettyTCM qname <+> text ":" <+> prettyType qtype

  -- TODO:
  -- * Check kind of the definition; group records/data type defs together

  pure BhModule
