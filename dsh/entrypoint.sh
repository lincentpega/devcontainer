#!/bin/sh
# dsh entrypoint: install the web profile's plugin bundles, then run the
# DeepSeek Harness web service behind a loopback relay.
# Mirrors the VPS unit's ExecStart:
#   node --expose-internals .../dsh/lib/bin.js web \
#     --host 127.0.0.1 --port 3080 --no-open [--trusted-host $DSH_TRUSTED_HOST]
# DSH intentionally refuses non-loopback binds (it guards against exposing
# remote code execution on the network), so it listens on the container's
# loopback only. Docker's port publish (docker-proxy) connects to the
# container's eth0 instead, so a socat relay accepts the published port there
# and forwards to dsh on loopback. The relay binds the eth0 address — never
# 0.0.0.0, which would also claim 127.0.0.1 and make dsh's own bind fail
# with EADDRINUSE. Host-facing exposure stays loopback-only: compose maps
# 127.0.0.1:${DSH_PORT} -> 3080.
set -eu

DSH_BIN="$(npm root -g)/@deepseek-ai/dsh/lib/bin.js"

# DSH does not install a profile's plugin bundles itself: boot aborts with
# "cannot resolve profile bundle ..." unless they are present in the profile
# dir. profiles/web declares @deepseek-ai/dsh-subagent-claude-code; install it
# on first boot (network + pnpm fetch), skip once node_modules is there.
PROFILE_WEB="$HOME/.dsh/profiles/web"
if [ ! -d "$PROFILE_WEB/node_modules/@deepseek-ai/dsh-subagent-claude-code" ]; then
    echo "[dsh] installing web profile bundles (first boot)..."
    dsh plugin --profile web install
fi

# Boot provisioning from compose env (.env): git identity + glab (GitLab CLI)
# auth. Runs on every boot: `git config --global` is idempotent, and `glab
# auth login` is idempotent too, so it self-heals token rotation. The git
# credential.helper for $GITLAB_HOST is pointed at glab so git push/pull over
# HTTPS authenticates with glab's token instead of prompting. glab state
# lands in $GLAB_CONFIG_DIR (= $HOME/.dsh/glab-cli, inside the ./dsh-config
# bind mount) and stays out of version control via dsh-config/.gitignore.
# Failures warn below and never abort the boot.
if [ -n "${GIT_USER_NAME:-}" ]; then
    git config --global user.name "${GIT_USER_NAME}" \
        || echo "[dsh] WARNING: git config user.name failed" >&2
fi
if [ -n "${GIT_USER_EMAIL:-}" ]; then
    git config --global user.email "${GIT_USER_EMAIL}" \
        || echo "[dsh] WARNING: git config user.email failed" >&2
fi
if [ -n "${GITLAB_HOST:-}" ]; then
    cred_host="${GITLAB_HOST%/}"
    git config --global "credential.${cred_host}.helper" '!glab auth git-credential' \
        || echo "[dsh] WARNING: git credential.helper config failed" >&2
fi

# GitHub over HTTPS: answer git's credential request from $GITHUB_TOKEN so the
# agent can push (e.g. lincentpega/devcontainer) without a host-side push. The
# helper reads the env var at request time, so no token lands in ~/.gitconfig;
# configured only when a token exists, which leaves public anonymous clones
# working unchanged when it does not.
if [ -n "${GITHUB_TOKEN:-}" ]; then
    gh_host="${GITHUB_HOST:-github.com}"
    gh_host="${gh_host#https://}"
    gh_host="${gh_host#http://}"
    gh_host="${gh_host%/}"
    git config --global "credential.${gh_host}.helper" \
        '!f() { test "$1" = get && test -n "${GITHUB_TOKEN:-}" && printf "username=x-access-token\npassword=%s\n" "$GITHUB_TOKEN"; }; f' \
        || echo "[dsh] WARNING: git github credential.helper config failed" >&2
    echo "[dsh] git will authenticate ${gh_host} with GITHUB_TOKEN"
fi
if [ -n "${GITLAB_HOST:-}" ] && [ -n "${GITLAB_TOKEN:-}" ]; then
    glab_host="${GITLAB_HOST#https://}"
    glab_host="${glab_host#http://}"
    if glab auth login --hostname "${glab_host}" --token "${GITLAB_TOKEN}" \
            </dev/null >/dev/null 2>&1; then
        echo "[dsh] glab authenticated for ${glab_host}"
    else
        echo "[dsh] WARNING: glab auth login failed for ${glab_host}" >&2
    fi
fi

if [ -n "${DSH_TRUSTED_HOST:-}" ]; then
    node --expose-internals "${DSH_BIN}" web \
        --host 127.0.0.1 --port 3080 --no-open \
        --trusted-host "${DSH_TRUSTED_HOST}" &
else
    node --expose-internals "${DSH_BIN}" web \
        --host 127.0.0.1 --port 3080 --no-open &
fi
DSH_PID=$!

trap 'kill "${DSH_PID}" "${SOCAT_PID}" 2>/dev/null || true; exit 143' TERM INT

HOST_IP="$(hostname -i | awk '{print $1}')"
socat "TCP-LISTEN:3080,bind=${HOST_IP},reuseaddr,fork" TCP:127.0.0.1:3080 &
SOCAT_PID=$!

wait "${DSH_PID}"
rc=$?
kill "${SOCAT_PID}" 2>/dev/null || true
exit "${rc}"
