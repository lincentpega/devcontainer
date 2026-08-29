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
  ~/.config/nvim (ro)
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

## Decisions baked in

| # | Decision | Value |
|---|---|---|
| D1 | tmux | host-side (A) — ssh pane into the box |
| D2 | git access | dedicated deploy keys |
| D3 | username | `dev` (UID 501 = host user) |
| D4 | JDK | 21 LTS |
| D5 | extras | gh CLI |
| D6 | Meridian | container-local |
| D7 | auth | interactive `claude login` |
| D8 | pi default | deepseek; Meridian switchable |
| D12 | workspace | `~/Development` rw |

## Portability

The recipe is the artifact: `docker compose up -d --build` reproduces the same
environment on any machine with Docker (arm64). The image bakes the tools;
your config + state live in the home volume. Ship configs in with a tar pipe.
