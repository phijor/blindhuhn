{
  name,
  ghcVersions,
  haskellPackages,
  haskell,
  linkFarmFromDrvs,
  lib,
}: let
  inherit (haskell.lib.compose) dontCheck;

  toPkg = version: {
    name = "${name}-${version}";
    value = haskell.packages.${version}.${name};
  };

  packages =
    builtins.listToAttrs (map toPkg ghcVersions)
    // {
      default = dontCheck haskellPackages.${name};
    };
in
  packages
  // {
    all = linkFarmFromDrvs "${name}-all" (
      lib.unique (lib.attrValues packages)
    );
  }
