#!/usr/bin/env bash

# ======================================================================
# Script: Prepare public-facing release staging directory
# ======================================================================
#
# Description:
# Assembles a clean copy of the repo suitable for pushing to the public
# GitHub mirror. Excludes:
#   - Scripts/            (internal release tooling)
#   - .gitlab-ci.yml,
#     .gitlab/            (GitLab-only config)
#   - build/              (release artifacts)
#   - .git/               (source repo history stays with GitLab)
#   - *.xcuserdata/,
#     xcuserdata/         (Xcode per-user state)
#   - .DS_Store           (macOS noise)
#   - README.internal.md,
#     RELEASE_NOTES.md    (if present — internal notes)
#
# Also parses the CHANGELOG entry for the given version into
# `build/release-notes.md` so `publish-github-release.sh` can use it.
#
# Usage:
#   ./Scripts/prepare-release.sh --version X.Y.Z
#
# Output:
#   build/release/          — the sync source for the public repo
#   build/release-notes.md  — the parsed release notes
#
# ======================================================================

set -euo pipefail

VERSION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        *)         echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    echo "Error: --version is required." >&2
    exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "$script_dir"/.. && pwd)"
build_dir="$root_dir/build"
staging_dir="$build_dir/release"

# Start clean
rm -rf "$staging_dir"
mkdir -p "$staging_dir"

echo "Staging directory: $staging_dir"

# Sync everything, excluding internal / build / editor state
rsync -av \
    --exclude "Scripts/" \
    --exclude ".gitlab-ci.yml" \
    --exclude ".gitlab/" \
    --exclude ".git/" \
    --exclude "build/" \
    --exclude "*.xcuserdata/" \
    --exclude "xcuserdata/" \
    --exclude ".DS_Store" \
    --exclude "README.internal.md" \
    --exclude "RELEASE_NOTES.md" \
    "$root_dir"/ "$staging_dir"/ >/dev/null

# Extra safety — belt-and-braces removal in case the excludes miss.
find "$staging_dir" -name ".DS_Store" -delete 2>/dev/null || true
find "$staging_dir" -name "xcuserdata" -type d -exec rm -rf {} + 2>/dev/null || true

# Sanity — Scripts/ must not be in the staging copy.
if [[ -d "$staging_dir/Scripts" ]]; then
    echo "Error: Scripts/ leaked into the staging directory. Aborting." >&2
    exit 1
fi

echo "Staging contents:"
ls -la "$staging_dir"

# ----- Parse release notes for this version ----------------------------
echo
echo "Parsing release notes for v$VERSION..."
cd "$script_dir"
python3 changelog-parser.py "$VERSION"

echo
echo "Prepared release staging directory."
