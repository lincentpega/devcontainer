# Meridian (Claude Max bridge) — dedicated service container.
# node:24-slim (debian/glibc) so the claude-code native binary from meridian's
# postinstall matches the runtime libc (per upstream's own Dockerfile note).
FROM node:24-slim

RUN npm install -g @rynfar/meridian

# pi-scrub plugin, baked at a fixed path referenced by config/meridian/plugins.json
RUN mkdir -p /opt/meridian/plugins \
    && cd /opt/meridian/plugins \
    && npm install --no-audit --no-fund @rynfar/meridian-plugin-pi-scrub

# Auth: OAuth token via MERIDIAN_PROFILES env (from .env) — no credential volumes.
# Config: mounted from repo at /root/.config/meridian (sdk-features.json, plugins.json).

CMD ["meridian"]
