#!/usr/bin/env bash

# ======================================================================
# Script: Validate BambuserCallsShopper release preconditions
# ======================================================================
#
# Description:
# Sanity-checks the local repo before cutting a release:
#   - Version follows semver
#   - Version isn't already tagged
#   - Working tree is clean
#   - CHANGELOG.md exists and has [Unreleased] content to promote
#   - `git`, `python3`, `rsync` are on PATH
#
# Usage:
#   ./Scripts/validate-release.sh --version X.Y.Z
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

# ----- Version format --------------------------------------------------
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: version '$VERSION' does not look like semver (X.Y.Z)." >&2
    exit 1
fi

# ----- Required tools --------------------------------------------------
for tool in git python3 rsync; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: '$tool' is not on PATH." >&2
        exit 1
    fi
done

# ----- Git state -------------------------------------------------------
cd "$root_dir"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: not inside a git working tree." >&2
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: working tree has uncommitted changes. Commit or stash first." >&2
    git status --short
    exit 1
fi

if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null; then
    echo "Error: tag 'v$VERSION' already exists locally." >&2
    exit 1
fi

# ----- CHANGELOG has content -------------------------------------------
if [[ ! -f "$root_dir/CHANGELOG.md" ]]; then
    echo "Error: CHANGELOG.md not found at repo root." >&2
    exit 1
fi

unreleased_body=$(awk '
    /^## \[Unreleased\]/ { start = 1; next }
    start && /^## \[/    { exit }
    start                { print }
' "$root_dir/CHANGELOG.md" | sed '/^\s*$/d')

if [[ -z "$unreleased_body" ]]; then
    echo "Error: CHANGELOG.md [Unreleased] section is empty — nothing to release." >&2
    exit 1
fi

echo "Validated. Ready to release v$VERSION."
