# builder-firecrawl-mcp

[firecrawl-mcp-server](https://github.com/firecrawl/firecrawl-mcp-server) for a self-hosted
Firecrawl instance, exposing only `firecrawl_scrape`. Built from the newest stable upstream tag
with [`patches/`](patches/) applied and published to `ghcr.io/koreapyj/firecrawl-mcp`.

Nothing is tagged: use `ghcr.io/koreapyj/firecrawl-mcp@sha256:...`. The digest of each build
is in the workflow run summary.

## Running

| Variable | |
|---|---|
| `FIRECRAWL_API_URL` | Required. |
| `FIRECRAWL_API_KEY` | Optional. |
| `HTTP_STREAMABLE_SERVER=true` | Streamable HTTP at `/mcp` instead of stdio. |
| `FIRECRAWL_MCP_ALLOWED_HOSTS` | Extra host names accepted in `Host`/`Origin` (HTTP mode). |

`summary`, `json` and `query` formats need an LLM provider on the Firecrawl instance.

## CI

Runs daily and on push / PR / dispatch. Skips when the upstream tag + patch set was already
published (recorded as an Actions cache entry). Only the default branch publishes.
`workflow_dispatch` takes `fc_ref` and `force`.

A failed run usually means a new upstream release no longer takes the patches with fuzz=0:

```sh
make clean prepare-src FC_REF=vX.Y.Z
make refresh
make build smoke
```
