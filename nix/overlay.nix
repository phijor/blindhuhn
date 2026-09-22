final: prev: {
  haskell = prev.haskell // {
    packageOverrides = final.lib.composeExtensions prev.haskell.packageOverrides (
      hself: hsuper:
      let
        inherit (final.haskell.lib.compose) overrideCabal;
        addBinToPath = overrideCabal (drv: {
          # `Setup.hs test` (used by nixpkgs' Haskell builder) doesn't put
          # build-tool-depends executables on PATH the way `cabal test` does,
          # so the golden tests' `callProcess "blindhuhn"` can't find the
          # just-built executable without this.
          preCheck = ''
            export PATH="$PWD/dist/build/blindhuhn:$PATH"
          ''
          + (drv.preCheck or "");
        });
        Blindhuhn = hself.callPackage ../Blindhuhn.nix { };
      in
      {
        Blindhuhn = final.lib.pipe Blindhuhn [
          addBinToPath
        ];
      }
    );
  };
}
