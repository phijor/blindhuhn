{ fetchzip, linkFarm }:

# Third-party JS assets needed to for the search UI injected into generated HTML.
# One subdirectory per vendored asset.  Embedded into the `blindhuhn` binary in
# `src/Blindhuhn/Search/Embed.hs`.
linkFarm "blindhuhn-vendored-assets" {
  # Fuzzy matching of search results.
  fzf = fetchzip {
    url = "https://registry.npmjs.org/fzf/-/fzf-0.5.2.tgz";
    hash = "sha256-iWD9j1dfd6VaiOoNv+mEYtqe0pPG6xo3FZZxcz7urUs=";
  };
}
