{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      inherit (pkgs.haskell.lib.compose) justStaticExecutables;
      blindhuhn = justStaticExecutables pkgs.haskellPackages.Blindhuhn;
    in
    {
      packages.blindhuhn = blindhuhn;
      packages.Blindhuhn = pkgs.haskellPackages.Blindhuhn;
      packages.default = config.packages.blindhuhn;

      apps.default = {
        type = "app";
        program = "${config.packages.default}/bin/Blindhuhn";
      };
    };
}
