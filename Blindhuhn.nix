{ mkDerivation, aeson, Agda, base, bytestring, containers, deepseq
, directory, file-embed, filepath, hashable, lib, process, tasty
, tasty-golden, tasty-hunit, template-haskell, temporary, text
, unordered-containers, uri-encode
}:
mkDerivation {
  pname = "Blindhuhn";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    aeson Agda base bytestring containers deepseq directory file-embed
    filepath hashable template-haskell text unordered-containers
    uri-encode
  ];
  executableHaskellDepends = [ base ];
  testHaskellDepends = [
    aeson base bytestring directory filepath process tasty tasty-golden
    tasty-hunit temporary text
  ];
  description = "Auch ein blindes Huhn findet mal ein Korn";
  license = lib.meta.getLicenseFromSpdxId "MIT";
  mainProgram = "blindhuhn";
}
