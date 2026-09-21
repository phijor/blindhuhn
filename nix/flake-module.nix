{ inputs, ... }:
{
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  imports = [
    inputs.git-hooks-nix.flakeModule
    ./treefmt.nix
    ./pkgs.nix
    ./packages.nix
    ./dev-shell.nix
  ];

  perSystem = {
    # Regenerate Blindhuhn.nix from Blindhuhn.cabal on commit.
    pre-commit.settings.hooks.cabal2nix = {
      enable = true;
      settings.outputFilename = "Blindhuhn.nix";
    };
  };

  flake.overlays.default = import ./overlay.nix;
}
