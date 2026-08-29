# devbox

A self-contained dev container for the pi agent, Claude Code, and Meridian
(Claude Max via the Agent SDK). Everything runs inside the container; the host
only mounts the workspace and your public keys.

## Quick start

```bash
orb start                      # start OrbStack (Docker daemon)
docker compose up -d --build   # build + start devbox
ssh -p 2222 dev@localhost      # land in the box
```

Web search works out of the box: the image bakes the official Tavily CLI
(`tvly`) and the Tavily Agent Skills live in the repo at `config/pi/skills/`
(mounted `~/.pi/agent/skills/`). Authenticate once (see below).

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
tmux (host-side, optional)              sshd           ← entry point :2222
IDE (VS Code Remote / JetBrains)   ◄──► pi (agent)
git push/pull (review loop)             Claude Code
                                        Meridian       127.0.0.1:3456
mounts:                                 nvim + LazyVim + jdtls (via mason)
  ~/Development → /workspace (rw)       tmux
  ~/.config/nvim (ro)                   config/tmux → ~/.tmux.conf (ro, in-box)
  ~/.ssh/authorized_keys (ro, pubkeys only)
```

- The **agent cannot reach anything that isn't mounted or loopback-bound** in
  the container: no photos, no docs, no private keys, no host loopback.
- Secrets/state that belong in the box live in the `devbox-home` volume:
  `~/.pi`, `~/.claude`, `~/.config/meridian`, nvim/mason state.

## Security envelope

- read-only rootfs (`/tmp`, `/run` = tmpfs; `/home/dev` = volume)
- `cap_drop: ALL`, with the minimal bootstrap set added back for sshd and the
  entrypoint: `NET_BIND_SERVICE`, `CHOWN`, `DAC_OVERRIDE`, `FOWNER`,
  `SYS_CHROOT`, `SETGID`, `SETUID`
- seccomp: Docker daemon default
- no docker.sock, no privileged mode
- you log in as `dev` (non-root); sshd runs as root by necessity
- host loopback services are **not** reachable from the container — if you ever
  need a host MCP server, use a narrow `ssh -R` tunnel (one port), not
  `host.docker.internal`

## Daily use

- **Agent**: `ssh -p 2222 dev@localhost` → `pi`
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
  `tavily-research`, …). Skills are repo-managed at `config/pi/skills/`
  (mounted `~/.pi/agent/skills/`, discovered by pi). Ask pi to "search the
  web" — it routes via the `tavily-search` skill. Raw CLI: `tvly search "..."`.

## Tavily auth (one-time, in the box)

Credentials live in `~/.tavily/config.json` on the `devbox-home` volume, so
they survive rebuilds — only authenticate once per box:

```bash
ssh -p 2222 dev@localhost
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
any tmux ≥ 3.2) and ssh into the box from a tmux pane. Restart tmux fully
(`tmux kill-server && tmux`) after changing it.

### Clipboard exchange (tmux buffer <-> system clipboard)

`set -g set-clipboard on` in the tmux config exchanges tmux's paste buffer
with the host clipboard via **OSC 52**:

- copy in tmux copy-mode (`prefix + [`, select, `y`) → tmux buffer **and** host
  clipboard (`prefix + ]` pastes the tmux buffer, Cmd+V the host clipboard);
- nvim yanks/paste use nvim's tmux clipboard provider (`load-buffer -w` /
  `refresh-client -l`) — `config/nvim/lua/config/options.lua` sets
  `clipboard = "unnamedplus"` (LazyVim disables it over SSH by default).

Requirements:

- a terminal with OSC 52 support (Ghostty/Kitty/WezTerm/iTerm2; macOS
  Terminal.app does not support it). Ghostty allows clipboard *writes* by
  default; to also let nvim *read* the host clipboard without a prompt, set
  `clipboard-read = allow` in `~/.config/ghostty/config` on D1.
- tmux must detect the terminal's `clipboard` feature (built-in for
  `xterm*`, which covers Ghostty) and run with `set-clipboard` on/external.

If tmux runs host-side on D1, the same tmux.conf applies there; nvim always
runs inside the box (its OSC 52 crosses the SSH session either way).

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

## First-boot checklist

1. `claude login` (OAuth — persists in the `devbox-home` volume)
2. `meridian` (binds 127.0.0.1:3456, container-local)
3. add pi provider override (above)
4. git: add your deploy keys to `~/.ssh` inside the box
5. `nvim` → LazyVim bootstrap → `:MasonInstall jdtls`
6. `tvly login` (Tavily web search — see above)

## Decisions baked in

| # | Decision | Value |
|---|---|---|
| D1 | tmux | host-side (A) — ssh pane into the box; config repo-managed at `config/tmux/tmux.conf` (mounted `~/.tmux.conf` in-box, same file usable host-side) |
| D2 | git access | dedicated deploy keys |
| D3 | username | `dev` (UID 501 = host user) |
| D4 | JDK | 21 LTS |
| D5 | extras | gh CLI |
| D6 | Meridian | container-local |
| D7 | auth | interactive `claude login` |
| D8 | pi default | deepseek; Meridian switchable |
| D9 | web search | official Tavily CLI (apt python3-venv + pip, isolated venv, image-baked) + skills repo-managed in `config/pi/skills/` |
| D12 | workspace | `~/Development` rw |

## Portability

The recipe is the artifact: `docker compose up -d --build` reproduces the same
environment on any machine with Docker (arm64). The image bakes the tools;
your config + state live in the home volume. Ship configs in with a tar pipe.
