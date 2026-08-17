#!/usr/bin/env bash

# ======================================================================
# Script: Create the GitHub Release entry for the pushed tag
# ======================================================================
#
# Description:
# Uses the `gh` CLI to create a Release attached to the vX.Y.Z tag, with
# `build/release-notes.md` (produced by `prepare-release.sh`) as the
# release body. No-op if `gh` isn't installed — the tag itself is
# enough to make the release traceable on the git side.
#
# Usage:
#   ./Scripts/publish-github-release.sh --version X.Y.Z
#
# Prerequisites:
#   - `gh auth login` (or GH_TOKEN env)
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

GITHUB_REMOTE="${GITHUB_REMOTE:-git@github.com:bambuser/BambuserCallsShopperSDK.git}"

if ! command -v gh >/dev/null 2>&1; then
    echo "Warning: 'gh' CLI not installed. Skipping GitHub Release creation." >&2
    echo "The tag v$VERSION was pushed and is enough for the release to be usable." >&2
    exit 0
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "$script_dir"/.. && pwd)"
notes_file="$root_dir/build/release-notes.md"
github_dir="$root_dir/build/github"

if [[ ! -f "$notes_file" ]]; then
    echo "Error: release notes not found at $notes_file. Run prepare-release.sh first." >&2
    exit 1
fi

# Extract owner/repo from the remote URL (works for both SSH + HTTPS)
repo=$(echo "$GITHUB_REMOTE" | sed -E 's#(git@github\.com:|https://github\.com/)##; s#\.git$##')

echo "Creating GitHub Release: $repo v$VERSION"

cd "$github_dir"
gh release create "v$VERSION" \
    --repo "$repo" \
    --title "v$VERSION" \
    --notes-file "$notes_file"

echo "GitHub Release v$VERSION created."
