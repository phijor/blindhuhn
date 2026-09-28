final: prev: {
  haskell = prev.haskell // {
    packageOverrides = final.lib.composeExtensions prev.haskell.packageOverrides (
      hself: hsuper:
      let
        inherit (final.haskell.lib.compose) overrideCabal;
        # Exclude *.nix files from source to prevent spurious rebuilds.
        excludeNixFiles = overrideCabal (drv: {
          src =
            let
              inherit (final.lib) fileset;
              root = ../.;
              nixFiles = fileset.fileFilter (file: file.hasExt "nix") root;
            in
            final.lib.fileset.toSource {
              inherit root;
              fileset = fileset.difference root nixFiles;
            };
        });
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
          excludeNixFiles
          addBinToPath
        ];
      }
    );
  };
}
