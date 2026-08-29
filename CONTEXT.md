# devbox — Context & Handoff

Purpose: transfer working context between sessions. Read this first when resuming
work on the dev container. Repo: `lincentpega/devcontainer` (GitHub).

## What this is

A self-contained dev environment for AI coding agents, running in Docker
(OrbStack on macOS). Everything lives in containers; the host mounts only the
workspace and repo configs.

- **devbox** — the working environment: pi (agent), LazyVim + jdtls, Claude Code,
  Node 24, JDK 21. Entry: `ssh -p 2222 dev@localhost` (alias `ssh devbox`).
- **meridian** — separate service container: Claude Max bridge for pi
  (Agent SDK → Anthropic API on `127.0.0.1:3456` / `meridian:3456`).

## Architecture

```
host (macOS) ── OrbStack
├── devbox        pi → http://meridian:3456 → Claude SDK → Anthropic (Claude Max)
│                   · sshd (2222) · nvim/LazyVim · claude (standalone login)
└── meridian      token via .env (MERIDIAN_PROFILES) · pi-scrub active
                    · config repo-managed (config/meridian/)

mounts (all repo-relative, portable):
  ${WORKSPACE:-../}:/workspace:rw      (projects dir — repo's parent by default)
  ./config/nvim:/home/dev/.config/nvim:ro
  ./config/pi:/home/dev/.pi/agent:rw   (pi can self-improve; state gitignored)
  ./config/meridian:/root/.config/meridian:rw
  devbox-home:/home/dev                (state volume: auth, sessions, mason)
```

## Secrets chain (no secrets in git)

```
.env (gitignored) → compose environment → container env
  → devbox: entrypoint writes ~/.devbox-env (sshd strips env from ssh sessions)
  → meridian: MERIDIAN_PROFILES=[{"id":"default","oauthToken":"${CLAUDE_OAUTH_TOKEN}"}]
```
- `.githooks/pre-commit` runs containerized gitleaks (`zricethezav/gitleaks`) +
  filename guard for `.env`/`auth.json`. Enabled via `core.hooksPath`.
- GitHub push protection = server-side backstop (enable in repo settings).
- `claude setup-token` (in devbox) generates the OAuth token for `.env`.

## Daily use

```bash
ssh devbox                    # or: ssh -p 2222 dev@localhost
pi                            # agent; /model → anthropic = Claude Max via meridian
nvim                          # LazyVim (java/vague/example plugins); :MasonInstall jdtls
git push/pull on HOST         # review loop — the box proposes, host publishes
```

## Status (verified working)

- devbox: Node 24.20, nvim 0.12.5, lazygit 0.64.1, pi 0.84.4, claude 2.1.251
- meridian: healthy, logged in, claude-opus-5 served, pi-scrub loaded (1 active)
- End-to-end pi → meridian → Claude Max: verified (minimal request returned)
- Security envelope: read-only rootfs, cap_drop ALL (+bootstrap set), no docker.sock,
  host loopback NOT reachable from containers (use `ssh -R` per-port if ever needed)

## Gotchas learned (don't re-debug)

1. `cap_drop: ALL` breaks sshd sandbox → add back `NET_BIND_SERVICE, CHOWN,
   DAC_OVERRIDE, FOWNER, SYS_CHROOT, SETGID, SETUID`
2. compose `seccomp=default` is parsed as a file path — omit it (daemon default)
3. npm `--ignore-scripts` skips claude-code's native binary postinstall — pi
   keeps `--ignore-scripts`, claude/meridian do NOT
4. sshd strips process env from ssh sessions → entrypoint writes `~/.devbox-env`
5. meridian in node:24-slim needs `/etc/machine-id` (absent → 500
   "cannot capture lock owner process incarnation") — baked in image
6. lazygit isn't packaged in Ubuntu 24.04 — install the official binary
7. mount targets in the volume can end up root-owned after removing a mount —
   fix via `docker exec -u root`

## Open items

- [ ] MERIDIAN_1M_CONTEXT_SUPPORT=0 — the only hard "no extra usage" switch
      (Sonnet 1M costs Extra Usage even on Max; Opus/Fable 1M are included)
- [ ] Enable GitHub push protection in repo settings
- [ ] Phase 3 — pi extensions:
      - permission modes (build/plan/ask/web-plan; /mode + Ctrl+Alt+P; gates:
        setActiveTools, tool_call block, system-prompt prohibition, path guard,
        trash-redirect) — D13..D16 pending
      - web_search tool adapter (Tavily via env; DDG fallback; secret in-process)
      - pi-mcp-adapter (host MCPs via ssh -R tunnel, only when needed)
- [ ] jdtls via mason (Java)
- [ ] Push from the box (deploy key) — only if trading the host review gate

## Key decisions (defaults taken)

tmux host-side · deploy keys (no ~/.ssh mount) · user `dev` (UID 501) ·
JDK 21 · Node 24 · meridian container-local → now own service · workspace =
repo parent · configs repo-managed · secrets .env-only · gitleaks containerized
