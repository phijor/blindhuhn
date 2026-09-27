{ ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      vendoredAssets = pkgs.callPackage ./vendored-assets.nix { };
      haskell-env = [
        pkgs.haskellPackages.cabal-install
        pkgs.haskellPackages.haskell-language-server
        pkgs.haskellPackages.implicit-hie
        pkgs.fourmolu
        pkgs.haskellPackages.hpack
        pkgs.cabal2nix
      ];
      web-env = [
        pkgs.nodejs
        pkgs.typescript-language-server
      ];
    in
    {
      devShells.default = pkgs.haskellPackages.shellFor {
        packages = p: [ p.Blindhuhn ];

        withHoogle = true;

        # Prevents cabal from choosing alternate plans, so that
        # *all* dependencies are provided by Nix.
        exactDeps = true;

        nativeBuildInputs = builtins.concatLists [
          haskell-env
          web-env
          config.pre-commit.settings.enabledPackages
        ];

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

        # Points Blindhuhn.Search.Embed at the assets it embeds, fetched
        # reproducibly by Nix rather than vendored in the repo. See
        # nix/vendored-assets.nix.
        BLINDHUHN_VENDORED_ASSETS_DIR = "${vendoredAssets}";
      };
    };
}
