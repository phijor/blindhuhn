{ ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.haskellPackages.shellFor {
        packages = p: [ p.Blindhuhn ];

        withHoogle = true;

        # Prevents cabal from choosing alternate plans, so that
        # *all* dependencies are provided by Nix.
        exactDeps = true;

        nativeBuildInputs = [
          pkgs.haskellPackages.cabal-install
          pkgs.haskellPackages.haskell-language-server
          pkgs.haskellPackages.implicit-hie
          pkgs.fourmolu
          pkgs.haskellPackages.hpack
          pkgs.cabal2nix
        ]
        ++ config.pre-commit.settings.enabledPackages;

        buildInputs = [
          pkgs.zlib.dev
          pkgs.zlib.out
          pkgs.icu
        ];

        # Installs the git hooks configured in nix/flake-module.nix.
        shellHook = config.pre-commit.shellHook;

        # Ensure nix commands do not use the global <nixpkgs> channel:
        NIX_PATH = "nixpkgs=" + pkgs.path;

        # Ensure system libraries (zlib.so, etc.) are visible to GHC:
        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
          pkgs.zlib
          pkgs.icu
        ];
      };
    };
}
