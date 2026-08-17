#!/usr/bin/env bash

# ======================================================================
# Script: Push the release staging directory to public GitHub
# ======================================================================
#
# Description:
# Clones the public GitHub mirror into build/github, mirrors the
# staging directory over it, commits "Release vX.Y.Z", tags, and pushes.
#
# The clone-and-mirror approach guarantees:
#   - Scripts/ and other internal files never touch the public repo
#     (they don't exist in the staging directory in the first place)
#   - Files DELETED in the internal repo also disappear on GitHub
#     (rsync --delete)
#   - The public repo's history is authored by whoever runs the script
#
# Usage:
#   ./Scripts/push-to-github.sh --version X.Y.Z [--dry-run]
#
# Environment:
#   GITHUB_REMOTE   Optional override for the public repo URL.
#                   Default: git@github.com:bambuser/BambuserCallsShopperSDK.git
#   GITHUB_BRANCH   Default: main
#
# ======================================================================

set -euo pipefail

VERSION=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        *)         echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    echo "Error: --version is required." >&2
    exit 1
fi

GITHUB_REMOTE="${GITHUB_REMOTE:-git@github.com:bambuser/BambuserCallsShopperSDK.git}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

script_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "$script_dir"/.. && pwd)"
build_dir="$root_dir/build"
staging_dir="$build_dir/release"
github_dir="$build_dir/github"

if [[ ! -d "$staging_dir" ]]; then
    echo "Error: '$staging_dir' does not exist. Run prepare-release.sh first." >&2
    exit 1
fi

# ----- Clone the public repo -------------------------------------------
rm -rf "$github_dir"
mkdir -p "$github_dir"

echo "Cloning $GITHUB_REMOTE ($GITHUB_BRANCH) → $github_dir ..."
git clone --branch "$GITHUB_BRANCH" --depth 1 "$GITHUB_REMOTE" "$github_dir"

# ----- Mirror the staging directory into the clone ---------------------
echo "Mirroring staging → clone (rsync --delete)..."
rsync -av --delete \
    --exclude ".git/" \
    "$staging_dir"/ "$github_dir"/ >/dev/null

# ----- Commit, tag, push -----------------------------------------------
cd "$github_dir"

# Configure the commit author only if none is set. Uses the operator's
# git config as the fallback.
if [[ -z "$(git config user.name || true)" ]]; then
    git config user.name  "Bambuser Release Bot"
fi
if [[ -z "$(git config user.email || true)" ]]; then
    git config user.email "sdk@bambuser.com"
fi

if [[ -z "$(git status --porcelain)" ]]; then
    echo "Nothing to commit — the public repo already matches the staging directory." >&2
    # Still create the tag if it doesn't exist so the release is
    # traceable.
fi

git add -A
if git diff --cached --quiet; then
    echo "(no file changes to commit)"
else
    git commit -m "Release v$VERSION"
fi

if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
    echo "Tag 'v$VERSION' already exists in the clone; skipping tag creation." >&2
else
    git tag -a "v$VERSION" -m "Release v$VERSION"
fi

if [[ $DRY_RUN -eq 1 ]]; then
    echo "(dry-run) would push: git push origin $GITHUB_BRANCH --follow-tags"
    echo "Skipping push."
    exit 0
fi

echo "Pushing $GITHUB_BRANCH + v$VERSION → $GITHUB_REMOTE ..."
git push origin "$GITHUB_BRANCH" --follow-tags

echo "Pushed v$VERSION to $GITHUB_REMOTE."
