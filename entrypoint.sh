#!/usr/bin/env bash
# devbox entrypoint: bring up sshd (the single entry point).
# /run is tmpfs (empty) and the rootfs is read-only — everything writable
# lives in volumes (/home/dev, /tmp) or tmpfs (/run).
set -e

USERNAME="dev"

# sshd needs /run/sshd
mkdir -p /run/sshd

# Install public keys from the read-only /auth mount (host ~/.ssh/authorized_keys).
# Only PUBLIC keys reach the container; private keys never mount.
# Note: only touch /home/dev/.ssh — it lives on the writable home volume;
# /home/dev/.config/nvim is a read-only host mount and must never be written.
if [ -f /auth/authorized_keys ]; then
    mkdir -p "/home/${USERNAME}/.ssh"
    cp /auth/authorized_keys "/home/${USERNAME}/.ssh/authorized_keys"
    chmod 700 "/home/${USERNAME}/.ssh"
    chmod 600 "/home/${USERNAME}/.ssh/authorized_keys"
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.ssh"
fi

# Surface container env vars into interactive ssh sessions.
# sshd strips the environment for non-interactive logins by default, so the
# values from compose `environment:` are written to a shell profile the user
# sources. Never contains real secrets by itself — values come from .env at
# compose time. The repo config files reference these as $ENV_VAR.
ENV_FILE="/home/${USERNAME}/.devbox-env"
: > "${ENV_FILE}"
for v in TAVILY_API_KEY DEEPSEEK_API_KEY GITLAB_HOST GITLAB_TOKEN; do
    val="${!v:-}"
    if [ -n "${val}" ]; then
        printf 'export %s=%q\n' "${v}" "${val}" >> "${ENV_FILE}"
    fi
done
chown "${USERNAME}:${USERNAME}" "${ENV_FILE}"
grep -q '\.devbox-env' "/home/${USERNAME}/.bashrc" 2>/dev/null \
    || echo 'source "$HOME/.devbox-env" 2>/dev/null || true' >> "/home/${USERNAME}/.bashrc"

echo "[devbox] sshd on :22 — log in as ${USERNAME}@localhost -p 2222"
exec /usr/sbin/sshd -D -e
