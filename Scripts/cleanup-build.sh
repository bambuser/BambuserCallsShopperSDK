#!/usr/bin/env bash

# ======================================================================
# Script: Remove release build artifacts
# ======================================================================
#
# Removes the build/ directory (staging copy + public clone + parsed
# release notes) after a successful release.
#
# Usage:
#   ./Scripts/cleanup-build.sh
#
# ======================================================================

set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
root_dir="$(cd "$script_dir"/.. && pwd)"
build_dir="$root_dir/build"

if [[ -d "$build_dir" ]]; then
    echo "Removing $build_dir ..."
    rm -rf "$build_dir"
    echo "Cleanup done."
else
    echo "Nothing to clean (build/ does not exist)."
fi
