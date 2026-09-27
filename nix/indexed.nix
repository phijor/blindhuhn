{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      blindhuhn = config.packages.blindhuhn;
      cubical = pkgs.agdaPackages.cubical;

      # A tiny Agda library consisting of a single generated module that
      # imports every module of `cubical`, so Blindhuhn's search index (and
      # the HTML it's injected into) cover the whole library. See
      # ./generate-cubical-index.sh, which mirrors agda/cubical's own
      # generate-everything.sh.
      cubicalIndexSrc = pkgs.runCommand "cubical-index-src" { } ''
        sh ${./generate-cubical-index.sh} \
          "${cubical}/${cubical.libraryFile}" \
          "${cubical.src}" \
          "$out"
      '';
      cubicalDocs = pkgs.agdaPackages.mkDerivation {
        pname = "cubical-docs";
        version = "0-unstable";
        meta = { };

        src = cubicalIndexSrc;
        buildInputs = [ cubical ];
        nativeBuildInputs = [ blindhuhn ];
        outputs = [
          "out"
          "html"
        ];

        # Generate HTML (with Blindhuhn's search UI injected) for every
        # module in the cubical library. `--library-file` is needed here
        # because `blindhuhn` doesn't know where to find the `cubical`
        # dependency in the store otherwise.
        postInstall = ''
          blindhuhn \
            --html \
            --blindhuhn-search \
            --blindhuhn-index cubical \
            --library-file=${pkgs.agdaPackages.mkLibraryFile [ cubical ]} \
            --html-dir "$html" \
            index.agda
        '';
      };

      # Serve generated docs locally.
      cubicalDocsServe = pkgs.writeShellApplication {
        name = "cubical-docs-serve";
        runtimeInputs = [ pkgs.python3 ];
        text = ''
          exec python3 ${./serve.py} ${cubicalDocs.html} "$@"
        '';
      };
    in
    {
      packages.cubical-docs = cubicalDocs;

      apps.cubical-docs = {
        type = "app";
        program = "${cubicalDocsServe}/bin/cubical-docs-serve";
      };
    };
}
