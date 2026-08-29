---
name: web-fetch
description: >-
  Use when you need a web page's readable content — docs, issues, blog posts,
  or any URL — rather than raw HTML. Free Readability extraction by default;
  opt-in paid Tavily for JS-rendered or bot-blocked pages. Load for "read
  this page", "summarize this article", or fetching page content.
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
