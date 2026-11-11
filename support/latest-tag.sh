#!/usr/bin/env bash
# Prints the newest stable vX.Y.Z tag of firecrawl-mcp-server.

set -euo pipefail

FC_GH_REPO="${FC_GH_REPO:-firecrawl/firecrawl-mcp-server}"
FC_REPO="${FC_REPO:-https://github.com/${FC_GH_REPO}.git}"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    tags="$(gh api --paginate "repos/${FC_GH_REPO}/git/matching-refs/tags/v" --jq '.[].ref')"
else
    tags="$(git ls-remote --tags --refs "${FC_REPO}" 'v*' | awk '{print $2}')"
fi

latest="$(printf '%s\n' "${tags}" \
    | sed 's#^refs/tags/##' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -n1 || true)"

if [ -z "${latest}" ]; then
    echo "error: no stable vX.Y.Z tag found in ${FC_GH_REPO}" >&2
    exit 1
fi

printf '%s\n' "${latest}"
