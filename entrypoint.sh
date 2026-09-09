#!/usr/bin/env bash
# devbox entrypoint: container keeper.
# There is no sshd — the box is entered with
#   docker compose exec -it -u dev devbox bash
# (VS Code Dev Containers / the pi harness do the same against the compose
# service). Compose `environment:` vars are inherited directly by exec'd
# processes, so no env-surface step is needed here.
# /run and /tmp are tmpfs (empty) and the rootfs is read-only — everything
# writable lives in volumes (/home/dev) or tmpfs.
set -e

USERNAME="dev"

# Boot-time (root) provisioning leaves root-owned entries in the home volume
# (.pi, .config, ...) that break the non-root agents — pi writes ~/.pi/mcp.json
# atomically as dev and fails with EACCES. Re-own any top-level entry not
# owned by dev each boot. Deliberately NOT recursive: .pi/agent and
# .config/nvim are separate host mounts owned on the host side.
find "/home/${USERNAME}" -maxdepth 1 -mindepth 1 \
    ! -user "${USERNAME}" \
    -exec chown "${USERNAME}:${USERNAME}" {} + 2>/dev/null || true

echo "[devbox] ready — enter with: docker compose exec -it -u dev devbox bash"
# Keep the container alive (PID 1); sessions are docker exec'd in.
exec sleep infinity
