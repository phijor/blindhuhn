{ mkDerivation, aeson, Agda, base, containers, deepseq, filepath
, lib, package-version, text, uri-encode
}:
mkDerivation {
  pname = "Blindhuhn";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    aeson Agda base containers deepseq filepath package-version text
    uri-encode
  ];
  executableHaskellDepends = [ base ];
  testHaskellDepends = [ aeson base text ];
  description = "Auch ein blindes Huhn findet mal ein Korn";
  license = lib.meta.getLicenseFromSpdxId "MIT";
  mainProgram = "Blindhuhn";
}
