# devbox

A self-contained dev container for the pi agent, Claude Code, Meridian
(Claude Max via the Agent SDK), and DeepSeek Harness (DSH). Everything runs
inside the container; the host only mounts the workspace and your repo
configs.

## Quick start

```bash
orb start                      # start OrbStack (Docker daemon)
docker compose up -d --build   # build + start devbox
docker compose exec -it -u dev devbox bash   # land in the box (see "Entering the box" below)
```

Web search works out of the box: the image bakes the official Tavily CLI
(`tvly`) and the Agent Skills live in the repo's canonical skill tree at
`.agents/skills/` — mounted `~/.agents/skills/` for pi and `~/.claude/skills/`
for Claude Code (available in every session/project); the repo `.claude/skills`
symlink also covers project work. Authenticate once (see below).

Destroy and rebuild for a fresh, identical environment (project files live on
the host mount, so they survive):

```bash
docker compose down
docker compose up -d --build
```

## Architecture

```
host (macOS)                            container (devbox)
────────────────────────                ─────────────────────────────
tmux (host-side, optional)              pi (agent)      ← entered via docker exec
IDE (VS Code Dev Containers)       ◄──► Claude Code
git push/pull (review loop)             Meridian       127.0.0.1:3456
Browser → http://127.0.0.1:3080   ◄──►  dsh (DeepSeek Harness)  127.0.0.1:3080
mounts:                                 nvim + LazyVim + jdtls (via mason)
  ~/Development → /workspace (rw)       tmux
  ~/.config/nvim (ro)                   config/tmux → ~/.tmux.conf (ro, in-box)
```

- The **agent cannot reach anything that isn't mounted or loopback-bound** in
  the container: no photos, no docs, no private keys, no host loopback.
- Secrets/state that belong in the box live in the `devbox-home` volume:
  pi/claude auth + sessions, `~/.config/meridian`, nvim/mason state. Hand-edited
  agent configs are repo-managed instead (`config/pi` → `~/.pi/agent`,
  `config/claude` → `~/.claude`).

## Security envelope

- read-only rootfs (`/tmp`, `/run` = tmpfs; `/home/dev` = volume)
- `cap_drop: ALL`, with only the entrypoint's home-ownership set added back:
  `CHOWN`, `DAC_OVERRIDE`, `FOWNER`
- seccomp: Docker daemon default
- no docker.sock, no privileged mode
- you log in as `dev` (non-root); the entrypoint runs as root by necessity
- host loopback services are **not** reachable from the container — if you ever
  need a host MCP server, use a narrow `ssh -R` tunnel from the box (one port),
  not `host.docker.internal`

## Daily use

- **Agent**: `docker compose exec -it -u dev devbox bash` → `pi`
- **Edit**: nvim with your LazyVim config (managed in-container; update via
  tar pipe, e.g. `tar -C ~/.config -xzf -`). Language servers via
  `:MasonInstall jdtls` (or your stack).
- **Review loop**: agent commits & pushes from the box → `git pull` on the host
  → review in any IDE → push back. Git history doubles as the agent audit log.
- **Claude Max via Meridian**: meridian runs as its own compose service
  (`docker compose up -d` starts both). Configure the OAuth token once
  (`claude setup-token` in the box → paste into `.env` → `compose up -d`).
  pi points at `http://meridian:3456` (compose network). Switch with `/model`.
- **Web search (Tavily)**: the official CLI (`tvly` 0.1.6, PyPI `tavily-cli`,
  pip-installed into an isolated venv at build time) plus 8 Tavily Agent
  Skills (`tavily-search`, `tavily-extract`, `tavily-map`, `tavily-crawl`,
  `tavily-research`, …). Skills are repo-managed at `.agents/skills/`
  (mounted `~/.agents/skills/`, discovered by pi). Ask pi to "search the
  web" — it routes via the `web-search` skill. Raw CLI: `tvly search "..."`.

## Entering the box

There is **no SSH server** — the devbox is entered with `docker compose exec`
from the host (run in the repo dir):

```bash
docker compose exec -it -u dev devbox bash
```

VS Code Dev Containers opens the same way via `devcontainer.json` (compose
service `devbox`, user `dev`). Prefer tmux for long sessions: run the exec
from a host-side tmux pane (below), or run tmux inside the box.

Optional host alias:

```bash
alias devbox='docker compose exec -it -u dev devbox bash'
```

Note: removing sshd does **not** affect git — the box keeps its ssh *client*
(deploy keys in `~/.ssh`) for pushing to remotes.

## Tavily auth (one-time, in the box)

Credentials live in `~/.tavily/config.json` on the `devbox-home` volume, so
they survive rebuilds — only authenticate once per box:

```bash
docker compose exec -it -u dev devbox bash
# then, inside the box:
tvly login          # browser OAuth (needs your host browser)
# or, headless:  tvly login --api-key tvly-...
tvly auth --json    # verify -> {"authenticated": true}
```

Optionally export `TAVILY_API_KEY` in the host `.env` for direct API use
(compose already passes it through).

## Tmux + pi

`config/tmux/tmux.conf` is the repo-managed tmux config (mounted read-only at
`~/.tmux.conf` inside the box). It restores the two things tmux otherwise
strips that pi needs:

- **`set -g mouse on`** — forwards mouse events to apps: click-to-focus
  panes, clicking moves the pi editor cursor, hyperlinks are clickable, and
  in pi's **fullscreen TUI mode** the wheel/trackpad scrolls the transcript.
- **`set -g extended-keys on`** — preserves modifier keys through tmux, so
  `Shift+Enter` (newline in the prompt), `Ctrl+Enter`, and `Alt+Enter`
  (queue follow-up) reach pi instead of collapsing into plain Enter. On
  tmux 3.5+ it also sets `extended-keys-format csi-u`, the most reliable
  format for pi; 3.2–3.4 fall back to xterm `modifyOtherKeys`, which pi
  supports too.

Scrolling in pi: `pi --tui-mode fullscreen` (or toggle in `/settings`) makes
pi own the viewport — wheel scrolls the transcript, `pageUp`/`pageDown`/
`home`/`end` page around, `ctrl+shift+f` searches it. In regular mode the
wheel scrolls tmux's scrollback instead (copy mode: `prefix + [`).

D1 runs tmux host-side: apply the same file to the host
(`cp config/tmux/tmux.conf ~/.tmux.conf` — it's version-guarded and works on
any tmux ≥ 3.2) and run `docker compose exec -it -u dev devbox bash` from a
tmux pane. Restart tmux fully (`tmux kill-server && tmux`) after changing it.

### Clipboard exchange (tmux buffer <-> system clipboard)

`set -g set-clipboard on` in the tmux config exchanges tmux's paste buffer
with the host clipboard via **OSC 52**:

- copy in tmux copy-mode (`prefix + [`, select, `y`) → tmux buffer **and** host
  clipboard (`prefix + ]` pastes the tmux buffer, Cmd+V the host clipboard);
- nvim yanks/paste reach the host clipboard via OSC 52 (relayed by tmux) —
  `config/nvim/lua/config/options.lua` sets `clipboard = "unnamedplus"`
  (kept enabled: LazyVim's SSH_CONNECTION special-case never fires in exec'd
  sessions).

Requirements:

- a terminal with OSC 52 support (Ghostty/Kitty/WezTerm/iTerm2; macOS
  Terminal.app does not support it). Ghostty allows clipboard *writes* by
  default; to also let nvim *read* the host clipboard without a prompt, set
  `clipboard-read = allow` in `~/.config/ghostty/config` on D1.
- tmux must detect the terminal's `clipboard` feature (built-in for
  `xterm*`, which covers Ghostty) and run with `set-clipboard` on/external.

If tmux runs host-side on D1, the same tmux.conf applies there; nvim always
runs inside the box (its OSC 52 crosses the docker exec session either way).

## Pi + Meridian wiring (one-time)

```json
// ~/.pi/agent/models.json
{
  "providers": {
    "anthropic": {
      "baseUrl": "http://127.0.0.1:3456",
      "apiKey": "x",
      "headers": { "x-meridian-agent": "pi" }
    }
  }
}
```

Pi runs in passthrough mode with Meridian by default (pi executes its own
tools; Meridian forwards `tool_use` blocks). Your deepseek provider stays
available — switch with `/model`.

### Pi + Meridian: prompt config (one-time, in the box)

Pi brings its own harness prompt, so the ~28 KB Claude Code system preset must
be off for the `pi` adapter, and the pi-scrub plugin strips pi's harness
fingerprint that Anthropic meters as extra usage:

```json
// ~/.config/meridian/sdk-features.json
{
  "pi": {
    "codeSystemPrompt": false,
    "clientSystemPrompt": true
  }
}
```

```bash
cd ~/.config/meridian
npm install @rynfar/meridian-plugin-pi-scrub
# register the dist/index.js absolute path in ~/.config/meridian/plugins.json
# then: curl -X POST http://127.0.0.1:3456/plugins/reload  (or restart meridian)
```

## DeepSeek Harness (dsh service)

`dsh` is a second compose service: the DeepSeek Harness web GUI, containerized
from the native systemd deployment that used to run on `dsh-vps`. Its DSH home
is the repo-managed `dsh-config/` tree (agent presets, skills, the `web`
profile with the cordis Redmine MCP), bind-mounted at `/home/dev/.dsh` inside
the container and writable — DSH maintains it at runtime the same way it did
on the VPS, and its nested `.gitignore` keeps sessions/caches/node_modules out
of git.

```bash
docker compose up -d --build dsh   # or plain `docker compose up -d --build`
# then open http://127.0.0.1:3080  (published loopback-only, never 0.0.0.0)
```

- The image pins the same toolchain as the VPS: Node.js 22, DSH `0.1.2-rc.1`,
  Claude Code `2.1.263`, mcp-remote `0.8.3`, pnpm `10.33.2`, uv `0.11.8`,
  glab `1.116.0`.
- Secrets come from the host `.env` (never the repo): `DEEPSEEK_API_KEY` is
  the default agent model key; `REDMINE_URL`/`REDMINE_API_KEY` feed the cordis
  Redmine MCP profile. See `.env.example`.
- **Agent workspace = the whole `dev` home**: dsh starts with cwd `/home/dev`,
  so agents operate across the home — including the `dsh-config` mount at
  `.dsh` — plus the projects dir mounted at `/home/dev/workspace` (the host
  `${WORKSPACE}` dir; `/workspace` is kept as a symlink so old absolute paths
  still resolve). The service runs as the same `dev` UID as devbox, so agent
  writes into `/home/dev/workspace` and `dsh-config` keep host ownership.
- `BARAKA_SERVICES_ROOT` is exported into both containers so the repo-mounted
  `create-worktree` skill finds the checkouts where they actually are:
  `/workspace` in devbox, `/home/dev/workspace` in dsh. The skill also detects
  the root on its own (walking up from the cwd, then `$HOME/workspace`), so the
  variable is an override rather than a requirement.
- GitHub over HTTPS works from inside the box: with `GITHUB_TOKEN` in `.env`,
  both entrypoints wire `credential.<GITHUB_HOST>.helper` so `git push` uses the
  token instead of prompting — the agent can push without a host-side step
  (`docker compose up -d` to re-run the entrypoint after adding the token). The
  helper reads the env var at request time, so no token is written to
  `~/.gitconfig`, and with no token set nothing changes for public clones.
- DSH refuses non-loopback binds by design, so inside the container it listens
  on loopback and the entrypoint's socat relay bridges the published port —
  the host-facing publish remains `127.0.0.1` only (see `dsh/entrypoint.sh`).
- First boot auto-installs the `web` profile bundles into the mounted
  `dsh-config` (the entrypoint runs `dsh plugin --profile web install` when
  they are missing — DSH does not install them itself; needs network once,
  then it is a no-op). The web UI emits a browser launch token in the
  container logs on each start — grab it with
  `docker compose logs dsh | sed -n 's/.*token=//p' | tail -1`.
- `DSH_TRUSTED_HOST` is only needed for non-loopback origins (e.g. a
  Tailscale URL); plain `http://127.0.0.1:3080` needs none.

## First-boot checklist

1. Enter the box: `docker compose exec -it -u dev devbox bash` (see above)
2. `claude login` (OAuth — persists in `config/claude/` in the repo, gitignored)
3. `meridian` (binds 127.0.0.1:3456, container-local)
4. add pi provider override (above)
5. git: add your deploy keys to `~/.ssh` inside the box
6. `nvim` → LazyVim bootstrap → `:MasonInstall jdtls`
7. `tvly login` (Tavily web search — see above)

## Decisions baked in

| # | Decision | Value |
|---|---|---|
| D1 | tmux | host-side (A) — `docker compose exec` pane into the box; config repo-managed at `config/tmux/tmux.conf` (mounted `~/.tmux.conf` in-box, same file usable host-side) |
| D2 | git access | dedicated deploy keys for GitLab; HTTPS token for GitHub (`GITHUB_TOKEN` → credential helper at boot) |
| D3 | username | `dev` (UID 501 = host user) |
| D4 | JDK | 21 LTS |
| D5 | extras | gh CLI |
| D6 | Meridian | container-local |
| D7 | auth | interactive `claude login` |
| D8 | pi default | deepseek; Meridian switchable |
| D9 | web search | official Tavily CLI (apt python3-venv + pip, isolated venv, image-baked) + skills repo-managed in `.agents/skills/` |
| D12 | workspace | `~/Development` rw |
| D17 | DeepSeek Harness | containerized `dsh` service (ported from the dsh-vps native deployment); DSH home = repo-managed `./dsh-config` at `/home/dev/.dsh` |

## Portability

The recipe is the artifact: `docker compose up -d --build` reproduces the same
environment on any machine with Docker (arm64). The image bakes the tools;
agent configs are repo-managed (`config/pi`, `config/claude`) and runtime state
lives in the home volume. Ship configs in with a tar pipe.
