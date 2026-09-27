module Golden (tests) where

import Control.Monad (filterM)
import Data.ByteString.Lazy (ByteString)
import Data.List (isInfixOf, sort)
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (CreateProcess (cwd), createProcess, proc, waitForProcess)
import Test.Tasty (TestName, TestTree, testGroup)
import Test.Tasty.Golden (goldenVsString)
import Test.Tasty.HUnit (assertBool, testCase, (@?=))

import Data.ByteString.Lazy qualified as BS
import Data.ByteString.Lazy.Char8 qualified as BS8

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
  pure $
    testGroup "golden" $
      concat $
        [ mkGoldenTest <$> names
        , searchTests
        ]

mkGoldenTest :: TestName -> TestTree
mkGoldenTest name =
  let testDir = goldenRoot </> name
  in goldenVsString
       name
       (testDir </> "index.golden")
       (runBlindhuhn testDir)

runProcess :: CreateProcess -> IO ()
runProcess process = do
  (_, _, _, hdl) <- createProcess process
  exitCode <- waitForProcess hdl
  exitCode @?= ExitSuccess
  pure ()

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
    runProcess $ blindhuhn {cwd = Just dir}
    BS.readFile (tmp </> "index.json")

searchTests :: [TestTree]
searchTests = [injectSearchUi, refusesReinjection]

-- | Run @Blindhuhn@ with @--html --blindhuhn-search@ on the "basic" golden
-- test's @Main.agda@, and check that the search UI assets were written and
-- injected into the generated HTML.
injectSearchUi :: TestTree
injectSearchUi =
  testCase "search: write and inject search UI assets" $
    withSystemTempDirectory "blindhuhn-golden-search" $ \tmp -> do
      let dir = goldenRoot </> "basic"
      let blindhuhn =
            proc
              "blindhuhn"
              ["--html", "--blindhuhn-search", "--blindhuhn-index", "test", "--html-dir", tmp, "Main.agda"]
      runProcess $ blindhuhn {cwd = Just dir}

      jsExists <- doesFileExist (tmp </> "blindhuhn-search.js")
      cssExists <- doesFileExist (tmp </> "blindhuhn-search.css")
      assertBool "blindhuhn-search.js was written" jsExists
      assertBool "blindhuhn-search.css was written" cssExists

      html <- BS8.readFile (tmp </> "Main.html")
      assertBool "search script tag was injected into Main.html" ("blindhuhn-search.js" `isInfixOf` BS8.unpack html)

-- | Rerunning @--blindhuhn-search@ over an output directory that already
-- has an injected @Main.html@ (without @--html@ to regenerate a clean
-- one) must refuse to run, with a nonzero exit code, rather than
-- double-inject or silently overwrite the previous injection.
refusesReinjection :: TestTree
refusesReinjection =
  testCase "search: refuses to re-inject into already-injected HTML" $
    withSystemTempDirectory "blindhuhn-golden-search-reinject" $ \tmp -> do
      let dir = goldenRoot </> "basic"
      let firstRun =
            proc
              "blindhuhn"
              ["--html", "--blindhuhn-search", "--blindhuhn-index", "test", "--html-dir", tmp, "Main.agda"]
      runProcess $ firstRun {cwd = Just dir}

      let secondRun =
            proc
              "blindhuhn"
              ["--blindhuhn-search", "--blindhuhn-index", "test", "--html-dir", tmp, "Main.agda"]
      (_, _, _, hdl) <- createProcess (secondRun {cwd = Just dir})
      exitCode <- waitForProcess hdl
      assertBool "rerun without --html over injected output fails" (exitCode /= ExitSuccess)
