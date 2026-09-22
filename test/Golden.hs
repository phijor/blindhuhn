module Golden (tests) where

import Control.Monad (filterM)
import Data.ByteString.Lazy (ByteString)
import Data.List (sort)
import System.Directory (doesDirectoryExist, listDirectory)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (CreateProcess (cwd), createProcess, proc, waitForProcess)
import Test.Tasty (TestName, TestTree, testGroup)
import Test.Tasty.Golden (goldenVsString)

import Data.ByteString.Lazy qualified as BS

goldenRoot :: FilePath
goldenRoot = "test/golden"

-- | Run golden tests in @goldenRoot@.
--
-- The subdirectories of @goldenRoot@ contain golden tests. For each
-- test, run @Blindhuhn@ on @Main.agda@, and compare the index it
-- generates against @index.golden@.  The test fails if there is a
-- mismatch between the output and the golden file.
tests :: IO TestTree
tests = do
  names <-
    (sort <$> listDirectory goldenRoot)
      >>= filterM (doesDirectoryExist . (goldenRoot </>))
  pure $ testGroup "golden" $ map mkGoldenTest names

mkGoldenTest :: TestName -> TestTree
mkGoldenTest name =
  let testDir = goldenRoot </> name
  in goldenVsString
       name
       (testDir </> "index.golden")
       (runBlindhuhn testDir)

-- | Run @Blindhuhn@ on @Main.agda@ in the test directory @dir@.
--
-- The generated @index.json@ is written to a scratch directory.
-- Its contents are read and returned as a byte string.
-- The scratch directory is then removed.
--
-- The @Blindhuhn@ is executable found via @build-tool-depends@.
--
-- Each test directory declare an Agda library with name "test"
-- in @test.agda-lib@.  @Blindhuhn@ is instructed to generated
-- index entries only for definitions beloning to this library
-- (via @--blindhuhn-index test@).  This makes sure that the
-- index it generates does not change just because an imported
-- module changed.  @Blindhuhn@ does not run the HTML backend
-- (@--html@ is ommited), thus does not generate any HTML files.
runBlindhuhn ::
  FilePath
  -- ^ Directory containing a single golden test
  -> IO ByteString
runBlindhuhn dir =
  withSystemTempDirectory "blindhuhn-golden" $ \tmp -> do
    let blindhuhn = proc "blindhuhn" ["--blindhuhn-index", "test", "--html-dir", tmp, "Main.agda"]
    (_, _, _, hdl) <- createProcess $ blindhuhn {cwd = Just dir}
    exitCode <- waitForProcess hdl
    case exitCode of
      ExitSuccess -> BS.readFile (tmp </> "index.json")
      ExitFailure r -> fail $ "Blinhuhn exited with code " ++ show r
