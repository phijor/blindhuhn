{ mkDerivation, Agda, base, deepseq, lib, package-version }:
mkDerivation {
  pname = "Blindhuhn";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [ Agda base deepseq package-version ];
  executableHaskellDepends = [ base ];
  testHaskellDepends = [ base ];
  description = "Auch ein blindes Huhn findet mal ein Korn";
  license = lib.licenses.mit;
  mainProgram = "Blindhuhn";
}
