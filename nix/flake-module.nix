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
    ./indexed.nix
  ];

  perSystem = {
    pre-commit.settings.hooks = {
      # Regenerate Blindhuhn.nix from Blindhuhn.cabal on commit.
      cabal2nix = {
        enable = true;
        settings.outputFilename = "Blindhuhn.nix";
      };
      # Make sure everything is formatted before commiting.
      treefmt.enable = true;
    };
  };

  flake.overlays.default = import ./overlay.nix;
}
