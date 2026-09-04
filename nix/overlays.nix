haskellOverlay: {
  default = final: prev: {
    haskell = prev.haskell // {
      packageOverrides = final.lib.composeExtensions prev.haskell.packageOverrides haskellOverlay;
    };
  };
}
