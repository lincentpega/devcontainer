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
- **`~/.pi/agent` is a repo mount** — skills and settings there are versioned
  and survive everything.
- Entry is SSH (`dev@localhost -p 2222`); compose env vars are surfaced in
  `~/.devbox-env` (sourced from `.bashrc`).

## For details

Load the `devbox-environment` skill for the full persistence table and
how-to-persist rules. Load `create-skill` before authoring/modifying skills.
