#!/bin/sh
# dsh entrypoint: start the DeepSeek Harness web service.
# Mirrors the VPS unit's ExecStart:
#   node --expose-internals .../dsh/lib/bin.js web \
#     --host 127.0.0.1 --port 3080 --no-open [--trusted-host $DSH_TRUSTED_HOST]
# Container-local loopback only; compose publishes 127.0.0.1:${DSH_PORT} on the
# host. --trusted-host is passed only when set — loopback origins need none.
set -eu

DSH_BIN="$(npm root -g)/@deepseek-ai/dsh/lib/bin.js"
PORT="${DSH_PORT:-3080}"

if [ -n "${DSH_TRUSTED_HOST:-}" ]; then
    exec node --expose-internals "${DSH_BIN}" web \
        --host 127.0.0.1 --port "${PORT}" --no-open \
        --trusted-host "${DSH_TRUSTED_HOST}"
fi

exec node --expose-internals "${DSH_BIN}" web \
    --host 127.0.0.1 --port "${PORT}" --no-open
