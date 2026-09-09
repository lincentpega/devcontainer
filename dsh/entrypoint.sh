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
# and forwards to dsh on loopback. Host-facing exposure stays loopback-only:
# compose maps 127.0.0.1:${DSH_PORT} -> 3080.
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

socat TCP-LISTEN:3080,bind=0.0.0.0,reuseaddr,fork TCP:127.0.0.1:3080 &
SOCAT_PID=$!

wait "${DSH_PID}"
rc=$?
kill "${SOCAT_PID}" 2>/dev/null || true
exit "${rc}"
