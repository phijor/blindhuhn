{
  lib,
  path,
  symlinkJoin,
  makeWrapper,
  haskellPackages,
  packages,
  pkgconfig,
  zlib,
  icu,
}: let
  cabal-with-nix = symlinkJoin {
    name = "cabal";
    paths = [haskellPackages.cabal-install];
    buildInputs = [makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/cabal --add-flags "--enable-nix"
    '';
  };

  buildInputs = [
    cabal-with-nix
    haskellPackages.haskell-language-server
    haskellPackages.implicit-hie
    haskellPackages.fourmolu
    haskellPackages.hpack

    pkgconfig
    zlib.dev
    zlib.out
    icu
  ];
in {
  default = haskellPackages.shellFor {
    inherit packages buildInputs;

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
