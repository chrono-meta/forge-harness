#!/usr/bin/env bash
set -e
v="$(node -p 'require("./package.json").version')"
read -p "Publish docs $v? [y/N] " ok
[ "$ok" = "y" ] || exit 1
python3 scripts/check_links.py docs/ || { touch .linkcheck_failed; exit 1; }
rm -f .linkcheck_failed
npm publish --access public
git push origin "docs-$v"
