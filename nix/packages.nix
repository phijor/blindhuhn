{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      inherit (pkgs.haskell.lib.compose) justStaticExecutables;
      blindhuhn = justStaticExecutables pkgs.haskellPackages.Blindhuhn;
    in
    {
      packages.default = blindhuhn;
      packages.Blindhuhn = pkgs.haskellPackages.Blindhuhn;

      apps.default = {
        type = "app";
        program = "${config.packages.default}/bin/Blindhuhn";
      };
    };
}
