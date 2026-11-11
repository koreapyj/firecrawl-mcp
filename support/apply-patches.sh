#!/usr/bin/env bash
# usage: support/apply-patches.sh <firecrawl-mcp-src-dir>
# Applies patches/series with --fuzz=0 so upstream drift fails instead of mis-applying.

set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
    echo "usage: $0 <firecrawl-mcp-src-dir>" >&2
    exit 2
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
src="$(cd "$1" && pwd)"

export QUILTRC="${root}/.quiltrc"
export QUILT_PATCHES="${root}/patches"

if grep -qvE '^[[:space:]]*(#|$)' "${QUILT_PATCHES}/series" 2>/dev/null; then
    rc=0
    (cd "${src}" && quilt push -a --fuzz=0) || rc=$?
    # quilt exits 2 when everything is already applied.
    if [ "${rc}" -ne 0 ] && [ "${rc}" -ne 2 ]; then
        echo "error: patch series failed to apply cleanly (fuzz=0) -- run 'make refresh'." >&2
        exit "${rc}"
    fi
    (cd "${src}" && quilt applied)
else
    echo "patches/series is empty -- building stock upstream."
fi
