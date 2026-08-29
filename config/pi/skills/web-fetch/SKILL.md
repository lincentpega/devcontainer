---
name: web-fetch
description: >-
  Fetch a page's readable content: free Readability extraction, opt-in paid
  Tavily. Use for reading docs, issues, or any URL.
compatibility: Requires uv (Python package manager; image-baked in the devbox devcontainer). Paid path needs the web-search skill's `web` CLI (tvly + TAVILY_API_KEY).
---

# Web Fetch

Fetch readable content from a URL. Free path by default (`scripts/fetch.py`:
Mozilla Readability + markdownify, deps auto-resolved via `uv run` PEP 723).
The Tavily-backed path is **opt-in via `--paid` — the agent decides** when the
metered quota is worth it.

## Usage

```bash
./scripts/fetch "https://docs.docker.com/..."                      # full page
./scripts/fetch "https://docs.python.org/..." --list-anchors       # heading map
./scripts/fetch "https://docs.python.org/..." --anchor argparse.ArgumentParser  # one section
./scripts/fetch "https://example.com" --paid --query "..."         # Tavily (metered)
```

- Always **quote URLs** — shells treat `?` and `&` specially.
- `--list-anchors` / `--anchor <id>`: browse and grab one docs section —
  focused and cheap, use before dumping a whole page.
- `--query` applies only to `--paid` (focused extraction, smaller/faster).
- Non-HTML (JSON, plain text) is returned as-is.

## Agent decision flow

1. Use the **free path** first.
2. Decide whether a paid call is worth it when:
   - the free fetch **fails** (4xx/5xx, bot-blocked, TLS, connection refused), or
   - the free output is **empty / garbled / nav-only** (JS-rendered SPA shell).
   - Retry with `--paid` (+ `--query` to focus).
3. Note: some sites (e.g. Stack Overflow) block **both** paths — no way through.

Exit codes: `0` ok, `2` bad usage, `3` `--paid` but web CLI missing, `4` free
path failed (missing uv or fetch error; retry with `--paid` at the agent's discretion).

## Attribution

`scripts/fetch.py` adapts the pipeline from
[full-stack-biz/fetch-urls-skill](https://github.com/full-stack-biz/fetch-urls-skill)
(Readability + markdownify, anchor extraction).
