module Golden (tests) where

import Control.Monad (filterM)
import Data.ByteString.Lazy (ByteString)
import Data.List (sort)
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (callProcess)
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
-- @Blindhuhn@ is instructed to only generated index entries for
-- definitions in @Main.agda@ (via @--blindhuhn-only-root@).
-- This way, the generated index should not change just because
-- an imported module changed.  The invocation does not run the
-- HTML backend (@--html@ is ommited), thus does not generate
-- any HTML files.
runBlindhuhn ::
  FilePath
  -- ^ Directory containing a single golden test
  -> IO ByteString
runBlindhuhn dir =
  withSystemTempDirectory "blindhuhn-golden" $ \tmp -> do
    callProcess
      "Blindhuhn"
      ["--no-libraries", "-i", dir, "--blindhuhn-only-root", "--html-dir", tmp, dir </> "Main.agda"]
    BS.readFile (tmp </> "index.json")
