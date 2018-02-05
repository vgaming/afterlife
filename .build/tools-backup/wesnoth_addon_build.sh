#!/bin/bash -eu
set -o pipefail
{

mkdir -p target


# remove newline, cut out commit hash
git describe --tags | cut -d '-' -f -2 | tr -d '\n' | tee target/version.txt
cat target/version.txt | tr '.-' '__' > target/version_nodot.txt


test -e build/docs_to_txt.lua && lua build/docs_to_txt.lua || wesnoth_addon_docs_sanitize.lua > target/about.txt


}; exit 0