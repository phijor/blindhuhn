{
  lib,
  path,
  symlinkJoin,
  makeWrapper,
  fourmolu,
  haskellPackages,
  packages,
  zlib,
  icu,
}:
let
  nativeBuildInputs = [
    haskellPackages.cabal-install
    haskellPackages.haskell-language-server
    haskellPackages.implicit-hie
    fourmolu
    haskellPackages.hpack
  ];
  buildInputs = [
    zlib.dev
    zlib.out
    icu
  ];
in
{
  default = haskellPackages.shellFor {
    inherit packages buildInputs nativeBuildInputs;

    withHoogle = true;

    # Prevents cabal from choosing alternate plans, so that
    # *all* dependencies are provided by Nix.
    exactDeps = true;

    # Ensure nix commands do not use the global <nixpkgs> channel:
    NIX_PATH = "nixpkgs=" + path;

    # Ensure system libraries (zlib.so, etc.) are visible to GHC:
    LD_LIBRARY_PATH = lib.makeLibraryPath buildInputs;
  };
}
