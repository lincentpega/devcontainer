# devbox — Context & Handoff

Purpose: transfer working context between sessions. Read this first when resuming
work on the dev container. Repo: `lincentpega/devcontainer` (GitHub).

## What this is

A self-contained dev environment for AI coding agents, running in Docker
(OrbStack on macOS). Everything lives in containers; the host mounts only the
workspace and repo configs.

- **devbox** — the working environment: pi (agent), LazyVim + jdtls, Claude Code,
  Node 24, JDK 21, official Tavily CLI (`tvly`) + Agent Skills for web search.
  Entry: `docker compose exec -it -u dev devbox bash` (no SSH).
- **meridian** — separate service container: Claude Max bridge for pi
  (Agent SDK → Anthropic API on `127.0.0.1:3456` / `meridian:3456`).
- **dsh** — separate service container: DeepSeek Harness web GUI, ported from
  the dsh-vps native deployment; DSH home = repo `./dsh-config` mounted at
  `/home/dev/.dsh`. GUI: `http://127.0.0.1:3080` (loopback-only publish).

## Architecture

```
host (macOS) ── OrbStack
├── devbox        pi → http://meridian:3456 → Claude SDK → Anthropic (Claude Max)
│                   · nvim/LazyVim · claude (standalone login)
├── meridian      token via .env (MERIDIAN_PROFILES) · pi-scrub active
│                   · config repo-managed (config/meridian/)
└── dsh           DeepSeek Harness web GUI (Node 22 image, VPS-pinned tools)
                    · DSH home = repo ./dsh-config → /home/dev/.dsh (rw)
                    · agent workspace = whole /home/dev (cwd); projects mount
                      ${WORKSPACE} → /home/dev/workspace (rw); /workspace symlink
                    · GUI published 127.0.0.1:3080 → container 3080 (via socat)

mounts (all repo-relative, portable):
  ${WORKSPACE:-../}:/workspace:rw      (projects dir — repo's parent by default)
  ./config/nvim:/home/dev/.config/nvim:ro
  ./config/pi:/home/dev/.pi/agent:rw   (pi can self-improve; state gitignored)
  ./.agents/skills:/home/dev/.agents/skills:rw   (canonical skill tree — pi global)
  ./.agents/skills:/home/dev/.claude/skills:rw   (same tree — claude user skills, every session/project)
  ./config/tmux/tmux.conf:/home/dev/.tmux.conf:ro   (mouse + extended keys for pi)
  ./config/meridian:/root/.config/meridian:rw
  devbox-home:/home/dev                (state volume: auth, sessions, mason)
  ./dsh-config:/home/dev/.dsh:rw       (dsh service: DSH home, repo-managed; runtime state gitignored by dsh-config/.gitignore)
  ${WORKSPACE:-../}:/home/dev/workspace:rw  (dsh service: host projects dir inside the dev home — whole /home/dev is the agent workspace; /workspace is a symlink to it in the image)
```

## Secrets chain (no secrets in git)

```
.env (gitignored) → compose environment → container env
  → devbox: no sshd — compose env is inherited directly by exec'd shells
  → meridian: MERIDIAN_PROFILES=[{"id":"default","oauthToken":"${CLAUDE_OAUTH_TOKEN}"}]
```
- `.githooks/pre-commit` runs containerized gitleaks (`zricethezav/gitleaks`) +
  filename guard for `.env`/`auth.json`. Enabled via `core.hooksPath`.
- GitHub push protection = server-side backstop (enable in repo settings).
- `claude setup-token` (in devbox) generates the OAuth token for `.env`.

## Daily use

```bash
docker compose exec -it -u dev devbox bash
pi                            # agent; /model → anthropic = Claude Max via meridian
nvim                          # LazyVim (java/vague/example plugins); :MasonInstall jdtls
git push/pull on HOST         # review loop — the box proposes, host publishes
```

## Status (verified working)

- devbox: Node 24.20, nvim 0.12.5, lazygit 0.64.1, pi 0.84.4, claude 2.1.251
- meridian: healthy, logged in, claude-opus-5 served, pi-scrub loaded (1 active)
- End-to-end pi → meridian → Claude Max: verified (minimal request returned)
- Tavily: official CLI `tvly` 0.1.6 (PyPI tavily-cli, apt python3-venv + pip
  into an isolated /opt/tavily venv) baked into the image; 8 Tavily Agent
  Skills repo-managed at `.agents/skills/` (canonical tree — mounted
  `~/.agents/skills/` for pi and `~/.claude/skills` for Claude Code; repo
  `.claude/skills` symlink for project work).
  CLI/install verified in the live box; auth NOT configured
  yet — run `tvly login` in the box once (credentials persist in `~/.tavily`
  on the home volume).
- Security envelope: read-only rootfs, cap_drop ALL (+entrypoint chown set: CHOWN,
  DAC_OVERRIDE, FOWNER), no docker.sock, host loopback NOT reachable from
  containers (use `ssh -R` per-port from the box if ever needed)
- dsh: compose service + `dsh/Dockerfile` added, `./dsh-config` populated from
  the dsh-vps deployment repo (VPS-pinned toolchain: Node 22, DSH 0.1.2-rc.1,
  claude-code, mcp-remote, pnpm, uv, glab). Entrypoint auto-installs the web
  profile bundles on first boot (`dsh plugin --profile web install` when
  `profiles/web/node_modules/@deepseek-ai/dsh-subagent-claude-code` is
  missing — DSH does NOT self-install them). Verified running on the VPS
  devcontainer clone at 127.0.0.1:3080 (Redmine MCP up); pnpm store lands
  under dsh-config/data (gitignored).

## Gotchas learned (don't re-debug)

1. `cap_drop: ALL` — the entrypoint's boot chown of root-owned home-volume
   entries needs `CHOWN, DAC_OVERRIDE, FOWNER`; nothing else (no sshd sandbox
   anymore)
2. compose `seccomp=default` is parsed as a file path — omit it (daemon default)
3. npm `--ignore-scripts` skips claude-code's native binary postinstall — pi
   keeps `--ignore-scripts`, claude/meridian do NOT
4. no sshd → no env stripping: `docker compose exec` inherits compose
   `environment:` directly (no `~/.devbox-env`)
5. meridian in node:24-slim needs `/etc/machine-id` (absent → 500
   "cannot capture lock owner process incarnation") — baked in image
6. lazygit isn't packaged in Ubuntu 24.04 — install the official binary
7. mount targets in the volume can end up root-owned after removing a mount —
   fix via `docker exec -u root`
8. meridian runtime state (profiles/, transcripts) leaks into rw-mounted config
   dirs — mount ONLY config files (sdk-features.json rw, plugins.json ro); state
   stays in the container layer

## Auth in the box

- Meridian (Claude Max): `CLAUDE_OAUTH_TOKEN` in `.env` → `MERIDIAN_PROFILES`
- deepseek (pi default provider): `config/pi/auth.json` (gitignored, mounted rw)
  — deepseek key only, extracted from host `~/.pi/agent/auth.json`

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
- [ ] dsh: verify the entrypoint auto-install path on a truly fresh clone
      (VPS verified via the manual install + skip path after rebuild)

## Key decisions (defaults taken)

tmux host-side (config repo-managed at config/tmux/, mounted ~/.tmux.conf) · deploy keys (no ~/.ssh mount) · user `dev` (UID 501) ·
JDK 21 · Node 24 · meridian container-local → now own service · workspace =
repo parent · configs repo-managed · skills canonical in `.agents/skills/` (pi + claude mounted `~/.agents/skills` / `~/.claude/skills`; repo `.claude/skills` symlink) · secrets .env-only · gitleaks containerized
