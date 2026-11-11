#!/usr/bin/env bash
# usage: support/smoke.sh <image>

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <image>" >&2
    exit 2
fi

here="$(cd "$(dirname "$0")" && pwd)"
image="$1"

if docker run --rm "${image}" >/dev/null 2>&1; then
    echo "error: image started without FIRECRAWL_API_URL" >&2
    exit 1
fi
echo "refuses to start without FIRECRAWL_API_URL: OK"

# No tool is called, so the API URL never has to answer.
node "${here}/smoke.mjs" docker run -i --rm \
    -e FIRECRAWL_API_URL=http://127.0.0.1:9 \
    "${image}"

echo "Smoke test passed for ${image}"
