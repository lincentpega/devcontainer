#!/bin/sh
# dsh entrypoint: install the web profile's plugin bundles, then start the
# DeepSeek Harness web service.
# Mirrors the VPS unit's ExecStart, adapted for Docker: the web app binds
# 0.0.0.0 *inside* the container because compose's port publish (docker-proxy)
# connects to the container's eth0, not its loopback — a 127.0.0.1 bind is
# unreachable through the publish. The host-facing side stays loopback-only:
# compose maps 127.0.0.1:${DSH_PORT} → 3080, so the GUI is never on 0.0.0.0.
# --trusted-host is passed only when set — loopback origins need none.
set -eu

DSH_BIN="$(npm root -g)/@deepseek-ai/dsh/lib/bin.js"
PORT="${DSH_PORT:-3080}"

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
    exec node --expose-internals "${DSH_BIN}" web \
        --host 0.0.0.0 --port "${PORT}" --no-open \
        --trusted-host "${DSH_TRUSTED_HOST}"
fi

exec node --expose-internals "${DSH_BIN}" web \
    --host 0.0.0.0 --port "${PORT}" --no-open
