{
  description = "Source search tool for Agda";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      ghcVersions = [ "ghc910" ];
    in
    {
      overlays = import ./nix/overlays.nix (
        hsfinal: _: {
          Blindhuhn = hsfinal.callCabal2nix "Blindhuhn" ./. { };
        }
      );
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
      in
      rec {
        packages = pkgs.callPackages ./nix/packages.nix {
          inherit ghcVersions;
          name = "Blindhuhn";
        };
        app = {
          blindhuhn = flake-utils.lib.mkApp {
            name = "blindhuhn";
            drv = packages.default;
          };
          default = app.blindhuhn;
        };
        devShells = pkgs.callPackages ./nix/dev-shells.nix {
          packages = p: [ p.Blindhuhn ];
        };

        formatter = pkgs.nixfmt;

        defaultPackage = packages.default;
        defaultApp = app.default;
        devShell = devShells.default;
      }
    );
}
