#!/usr/bin/env sh
# Generates a tiny Agda library consisting of a single module that imports
# every module of a `cubical` checkout, so Blindhuhn's search index (and
# the HTML it's injected into) cover the whole library. The import list is
# generated the same way agda/cubical generates its own Cubical.Everything:
# https://github.com/agda/cubical/blob/master/generate-everything.sh
set -eu

agda_lib="$1" # path to cubical's installed .agda-lib file
src="$2"      # path to cubical's source tree (containing Cubical/)
out="$3"      # output directory to write the library into

name=$(sed -n 's/^name: *//p' "$agda_lib")
flags=$(sed -n 's/^flags: *//p' "$agda_lib")

mkdir -p "$out"

{
  echo "name: index"
  echo "include: ."
  echo "depend: $name"
  # cubical's own flags (e.g. --cubical) are infectious: a module compiled
  # with them can only be imported from a module compiled with them too.
  echo "flags: $flags"
} >"$out/index.agda-lib"

{
  printf 'module index where\n\n'
  find "$src/Cubical" -type f -name '*.agda' '!' -path "$src/Cubical/Everything.agda" |
    sed -e "s|^$src/||" -e 's/\//./g' -e 's/\.agda$//' -e 's/^/import /' |
    sort
} >"$out/index.agda"
