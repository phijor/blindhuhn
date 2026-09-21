{ ... }:
{
  perSystem = { pkgs, config, ... }: {
    packages.default = pkgs.haskellPackages.Blindhuhn;
    packages.Blindhuhn = pkgs.haskellPackages.Blindhuhn;

    apps.default = {
      type = "app";
      program = "${config.packages.default}/bin/Blindhuhn";
    };
  };
}
