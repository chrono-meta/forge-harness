#!/usr/bin/env bash
# Tag, push and release. Asks first.
set -e
tag="$1"
read -p "Ship $tag? Confirm before we push [y/N] " ok
[ "$ok" = "y" ] || exit 1
git tag "$tag"
git push origin --tags
gh release create "$tag" --notes-file notes.md
