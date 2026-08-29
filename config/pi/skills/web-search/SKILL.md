---
name: web-search
description: >-
  Use when you need up-to-date web information: docs, error messages, config
  examples, current events, or answers outside the model's knowledge. Load
  for "search the web", "what's the latest", or verifying facts — even if
  the user doesn't say "search".
compatibility: Requires scripts/web (wraps tvly, image-baked; auth via TAVILY_API_KEY).
---

# Web Search

Search the web with `scripts/web`, run **relative to this skill directory**:

| Need | Command |
|------|---------|
| Find pages / answer a question | `./scripts/web search "query"` |

## Examples

```bash
./scripts/web search "nginx 502 bad gateway" --domain stackoverflow.com   # one domain
./scripts/web search "k8s ingress annotation" --days 30                   # recent only
./scripts/web search "postgres connection pool" --answer                  # + AI answer
./scripts/web search "query" -n 10 --json                                 # 10 results as JSON
echo "query" | ./scripts/web search -                                     # stdin
```

Flags: `-n/--num` (default 5), `--domain` (repeatable), `--exclude-domain`,
`--days N`, `--depth`, `--topic news|finance`, `--answer`, `--country`, `--json`.

Exit codes: `0` ok, `2` bad usage, `3` not ready (missing tvly/auth), `4` API error.
Results are LLM-optimized: titles, URLs, and concise snippets.
