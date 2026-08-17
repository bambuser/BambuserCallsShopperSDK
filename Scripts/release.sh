#!/usr/bin/env bash

# ======================================================================
# Script: Release BambuserCallsShopper to public GitHub
# ======================================================================
#
# Description:
# Cuts a public release of the SDK from the internal GitLab repo to the
# public GitHub mirror at:
#
#     https://github.com/bambuser/BambuserCallsShopperSDK
#
# Steps:
#   1. Validate git state + version format + CHANGELOG has content.
#   2. Move [Unreleased] entries in CHANGELOG.md into a new [X.Y.Z]
#      section with today's date, commit + push to GitLab.
#   3. Assemble a clean staging copy of the public-facing files
#      (excludes Scripts/, .gitlab*, internal notes).
#   4. Sync the staging copy into a local clone of the public repo,
#      commit "Release vX.Y.Z", tag, push main + tags.
#   5. Optionally create a GitHub Release with the parsed CHANGELOG
#      entry as release notes (requires `gh` CLI).
#   6. Clean up build artifacts.
#
# Usage:
#   ./Scripts/release.sh --version 0.3.0 [--dry-run] [--no-gh-release]
#
# Prerequisites:
#   - git, python3, rsync
#   - SSH access to the public GitHub repo (or `gh auth login`)
#   - Clean working tree on the internal repo's release branch
#
# ======================================================================

set -euo pipefail

VERSION=""
DRY_RUN=0
CREATE_GH_RELEASE=1

usage() {
    cat <<EOF
Usage: $0 --version X.Y.Z [--dry-run] [--no-gh-release]

Options:
    --version X.Y.Z     Semver version to release (required).
    --dry-run           Do everything except push + tag + gh release.
    --no-gh-release     Skip creating the GitHub Release entry.
    -h, --help          Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)      VERSION="$2"; shift 2 ;;
        --dry-run)      DRY_RUN=1; shift ;;
        --no-gh-release) CREATE_GH_RELEASE=0; shift ;;
        -h|--help)      usage; exit 0 ;;
        *)              echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    echo "Error: --version is required." >&2
    usage
    exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "$script_dir"/.. && pwd)"
build_dir="$root_dir/build"

echo "==================================================================="
echo "Releasing BambuserCallsShopper v$VERSION"
echo "  root:     $root_dir"
echo "  build:    $build_dir"
echo "  dry-run:  $DRY_RUN"
echo "==================================================================="

# ----- 1. Validate -----------------------------------------------------
echo
echo ">>> Validating release preconditions..."
"$script_dir"/validate-release.sh --version "$VERSION"

# ----- 2. Update CHANGELOG.md ------------------------------------------
echo
echo ">>> Moving [Unreleased] entries into [$VERSION] section..."
cd "$script_dir"
python3 changelog-updater.py "$VERSION"

if [[ $DRY_RUN -eq 0 ]]; then
    cd "$root_dir"
    git add CHANGELOG.md
    git commit -m "chore(release): update changelog for v$VERSION"
    git push
else
    echo "(dry-run) skipping CHANGELOG.md commit/push"
fi

# ----- 3. Prepare release staging directory ----------------------------
echo
echo ">>> Preparing release staging directory..."
"$script_dir"/prepare-release.sh --version "$VERSION"

# ----- 4. Push to public GitHub ----------------------------------------
echo
echo ">>> Syncing to public GitHub repo..."
if [[ $DRY_RUN -eq 0 ]]; then
    "$script_dir"/push-to-github.sh --version "$VERSION"
else
    "$script_dir"/push-to-github.sh --version "$VERSION" --dry-run
fi

# ----- 5. Create GitHub Release ----------------------------------------
if [[ $CREATE_GH_RELEASE -eq 1 ]]; then
    echo
    echo ">>> Creating GitHub Release..."
    if [[ $DRY_RUN -eq 0 ]]; then
        "$script_dir"/publish-github-release.sh --version "$VERSION"
    else
        echo "(dry-run) skipping gh release create"
    fi
else
    echo "(--no-gh-release) skipping GitHub Release creation"
fi

# ----- 6. Cleanup ------------------------------------------------------
echo
echo ">>> Cleaning up build artifacts..."
"$script_dir"/cleanup-build.sh

echo
echo "==================================================================="
echo "Release v$VERSION complete."
echo "==================================================================="
