{ mkDerivation, aeson, Agda, base, containers, deepseq, filepath
, lib, text, uri-encode
}:
mkDerivation {
  pname = "Blindhuhn";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    aeson Agda base containers deepseq filepath text uri-encode
  ];
  executableHaskellDepends = [ base ];
  testHaskellDepends = [ aeson base text ];
  description = "Auch ein blindes Huhn findet mal ein Korn";
  license = lib.meta.getLicenseFromSpdxId "MIT";
  mainProgram = "Blindhuhn";
}
