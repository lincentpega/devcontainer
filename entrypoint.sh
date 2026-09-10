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

# Boot provisioning for the dev user from compose env (.env):
#   * git identity   -> git config --global (persists in the devbox-home volume)
#   * glab auth      -> idempotent login each boot (self-heals token rotation)
#   * git cred helper -> git push/pull over HTTPS on $GITLAB_HOST uses glab's
#                        token, and on $GITHUB_HOST the $GITHUB_TOKEN, instead of
#                        prompting (credential.helper per host)
# Runs as root, applies as `dev`; failures warn but never abort container boot.
if command -v runuser >/dev/null 2>&1; then
    if [ -n "${GIT_USER_NAME:-}" ]; then
        runuser -u dev -- env HOME=/home/dev git config --global user.name "${GIT_USER_NAME}" \
            || echo "[devbox] WARNING: git config user.name failed" >&2
    fi
    if [ -n "${GIT_USER_EMAIL:-}" ]; then
        runuser -u dev -- env HOME=/home/dev git config --global user.email "${GIT_USER_EMAIL}" \
            || echo "[devbox] WARNING: git config user.email failed" >&2
    fi
    if [ -n "${GITLAB_HOST:-}" ]; then
        cred_host="${GITLAB_HOST%/}"
        runuser -u dev -- env HOME=/home/dev git config --global \
            "credential.${cred_host}.helper" '!glab auth git-credential' \
            || echo "[devbox] WARNING: git credential.helper config failed" >&2
    fi
    # GitHub over HTTPS: answer git's credential request from $GITHUB_TOKEN. The
    # helper reads the env var at request time, so no token is written to
    # ~/.gitconfig; configured only when a token exists, which leaves public
    # anonymous clones working unchanged when it does not.
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        gh_host="${GITHUB_HOST:-github.com}"
        gh_host="${gh_host#https://}"
        gh_host="${gh_host#http://}"
        gh_host="${gh_host%/}"
        runuser -u dev -- env HOME=/home/dev git config --global \
            "credential.${gh_host}.helper" \
            '!f() { test "$1" = get && test -n "${GITHUB_TOKEN:-}" && printf "username=x-access-token\npassword=%s\n" "$GITHUB_TOKEN"; }; f' \
            || echo "[devbox] WARNING: git github credential.helper config failed" >&2
        echo "[devbox] git will authenticate ${gh_host} with GITHUB_TOKEN"
    fi
    if [ -n "${GITLAB_HOST:-}" ] && [ -n "${GITLAB_TOKEN:-}" ]; then
        glab_host="${GITLAB_HOST#https://}"
        glab_host="${glab_host#http://}"
        mkdir -p /home/dev/.dsh/glab-cli
        chown dev:dev /home/dev/.dsh /home/dev/.dsh/glab-cli 2>/dev/null || true
        if runuser -u dev -- env HOME=/home/dev GLAB_CONFIG_DIR=/home/dev/.dsh/glab-cli \
                glab auth login --hostname "${glab_host}" --token "${GITLAB_TOKEN}" \
                </dev/null >/dev/null 2>&1; then
            echo "[devbox] glab authenticated for ${glab_host}"
        else
            echo "[devbox] WARNING: glab auth login failed for ${glab_host}" >&2
        fi
    fi
else
    echo "[devbox] WARNING: runuser unavailable; git identity/glab not provisioned" >&2
fi

echo "[devbox] ready — enter with: docker compose exec -it -u dev devbox bash"
# Keep the container alive (PID 1); sessions are docker exec'd in.
exec sleep infinity
