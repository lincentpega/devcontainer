---
name: devbox-environment
description: >-
  Use when working in the devbox devcontainer: installing tools, changing
  configs, or deciding whether something survives a restart, rebuild, or
  docker compose down -v. Covers the read-only rootfs and persistence rules.
  Load for apt-get, Dockerfile changes, or "will this persist?" questions.
compatibility: devbox devcontainer (Ubuntu 24.04).
---

# Devbox Environment

The container runs the **devbox** devcontainer (Ubuntu 24.04). Knowing what is
writable and what persists is the #1 thing that determines whether your changes
survive a container restart/rebuild.

## Key facts

- **Rootfs is read-only at runtime.** No `apt-get install`, no writes to
  `/usr`, `/usr/local`, `/opt`. System-level changes belong in the devcontainer's
  Dockerfile, which requires a rebuild.
- **`/workspace` is a bind mount — fully persistent.** All project code lives
  here.
- **`/home/dev` is the `devbox-home` named volume.** Survives restart and
  rebuild, but is **lost on `docker compose down -v` or a fresh machine**.
  Do not put anything important here that isn't reproducible.
- **`/tmp` and `/run` are tmpfs** — wiped on restart. Scratch space only.
- **Entry point is SSH** (`dev@localhost -p 2222`). Compose env vars
  (`TAVILY_API_KEY`, `DEEPSEEK_API_KEY`, `GITLAB_HOST`, `GITLAB_TOKEN`) are
  written to `~/.devbox-env`, sourced from `.bashrc`.

## What survives what

| Storage | Restart | Rebuild | down -v / fresh |
|---------|---------|---------|-----------------|
| `/workspace/**` (projects) — bind mount | ✅ | ✅ | ✅ |
| Repo-mounted configs (`~/.pi/agent`, `~/.config/nvim`, `~/.tmux.conf`) | ✅ | ✅ | ✅ |
| Home volume (`~/.local/**`, `~/.tavily`, `~/.claude`, sessions) | ✅ | ✅ | ❌ |
| Image layer (`/usr/local/bin`, `/opt`) | ✅ | ❌* | ✅ |
| tmpfs (`/tmp`, `/run`) | ❌ | ❌ | ❌ |

\* Rebuilds lose image-layer state only if the Dockerfile doesn't recreate it
(rebuilds re-run the Dockerfile, so baked-in tools survive).

## How to persist new things

1. **A skill / skill tooling** → see the `create-skill` skill for structure
   and conventions. Skills live in `/home/dev/.pi/agent/skills/` — a repo
   mount, so anything there persists and is versioned.
2. **A pi skill / config** → `/home/dev/.pi/agent/...` is a repo mount — just
   create it there, it persists and is versioned.
3. **A system package** → edit the devcontainer's Dockerfile and rebuild
   (`docker compose build`). Runtime apt is impossible (read-only rootfs).
4. **Startup wiring** → edit the devcontainer's entrypoint script (runs as root
   on every start; keep it idempotent).
5. **An env var** → add to the devcontainer's compose `environment:` (and `.env`
   at compose time). Do NOT hardcode secrets in shell profiles.
6. **Auth state** (OAuth tokens, logins) → allowed on the home volume
   (`~/.tavily`, `~/.claude`), it survives restarts; re-auth only after
   `down -v`.

## Available tooling (image-baked, always present)

`tvly` (web search/fetch), `uv` (PEP 723 script runner), `gh`, `glab`, Node.js 24, `python3`, `nvim`
(LazyVim), `lazygit`, `fd`, `rg`, `fzf`, `jq`, `tmux`, `git`, OpenJDK 21.

## Validation

Before claiming something persists, verify the mount source:
`mount | grep -E "workspace|home/dev"`. A wrong persistence claim causes
lost work — check, don't assume.
