# Environment: devbox devcontainer

You are running inside the **devbox** devcontainer (Ubuntu 24.04).

## Critical facts

- **Rootfs is READ-ONLY at runtime.** No `apt-get install`; no writes to
  `/usr`, `/usr/local`, `/opt`. System-level changes require editing the
  devcontainer's Dockerfile and rebuilding (`docker compose build`).
- **`/workspace` is a persistent bind mount** — all project code lives here
  and survives everything.
- **`/home/dev` is the `devbox-home` volume** — survives restarts/rebuilds,
  but is **lost on `docker compose down -v` or a fresh machine**. Don't put
  anything important there that isn't reproducible.
- **`/tmp` and `/run` are tmpfs** — wiped on restart; scratch space only.
- **`~/.pi/agent` is a repo mount** — pi settings/AGENTS.md there are versioned
  and survive everything.
- **Skills live in the repo's canonical `.agents/skills/`** — mounted at
  `~/.agents/skills/` (pi, every session) and `~/.claude/skills/` (Claude
  Code, every session/project), plus the repo's `.claude/skills` symlink;
  all versioned.
- Entry is `docker compose exec -it -u dev devbox bash` (from the repo dir on
  the host; VS Code Dev Containers / the pi harness do the same). No SSH.
  Compose env vars (`TAVILY_API_KEY`, `DEEPSEEK_API_KEY`, …) are inherited
  directly by exec'd shells — there is no `~/.devbox-env` anymore.

## For details

Load the `devbox-environment` skill for the full persistence table and
how-to-persist rules. Load `create-skill` before authoring/modifying skills.
