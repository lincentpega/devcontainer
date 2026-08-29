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

echo "[devbox] sshd on :22 — log in as ${USERNAME}@localhost -p 2222"
exec /usr/sbin/sshd -D -e
