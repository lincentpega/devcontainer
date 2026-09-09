# dsh — DeepSeek Harness web service, containerized
# Port of the native VPS deployment (dsh-vps, /home/dsh/deepseek-harness):
# the same pinned toolchain and the same DSH home layout, so ./dsh-config
# (the versioned DSH home, bind-mounted at /home/dev/.dsh) is interchangeable
# with the VPS dsh-config. Secrets arrive via compose env from the host .env.
# Base: Ubuntu 24.04 LTS, arm64/amd64

FROM ubuntu:24.04

ARG TARGETARCH
ARG USERNAME=dev
ARG USER_UID=501
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Base packages — the harness agents shell out to git/ssh/curl/python; socat
# bridges the published port to dsh, which must bind the container loopback
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git openssh-client socat \
        python3 python3-pip python3-venv jq \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Node.js 22 LTS — the VPS pin (22.22.2) that DSH 0.1.2-rc.1 runs under
# ---------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Agent tools (npm globals), pinned to the VPS versions
# ---------------------------------------------------------------------------
RUN npm install -g --no-audit --no-fund \
        @deepseek-ai/dsh@0.1.2-rc.1 \
        @anthropic-ai/claude-code@2.1.263 \
        mcp-remote@0.8.3

# pnpm — DSH installs profile bundles with it (pinned like the VPS)
RUN corepack enable && corepack prepare pnpm@10.33.2 --activate

# ---------------------------------------------------------------------------
# uv/uvx — the cordis Redmine MCP profile (dsh-config/profiles/web) runs
# its server through `uvx`; uv state goes to UV_CACHE_DIR under the DSH home
# ---------------------------------------------------------------------------
RUN python3 -m venv /opt/uv \
    && /opt/uv/bin/pip install --no-cache-dir uv==0.11.8 \
    && ln -s /opt/uv/bin/uv /usr/local/bin/uv \
    && ln -s /opt/uv/bin/uvx /usr/local/bin/uvx

# ---------------------------------------------------------------------------
# glab (GitLab CLI) — deb package, pinned, TARGETARCH-aware (arm64/amd64)
# ---------------------------------------------------------------------------
ARG GLAB_VERSION=v1.116.0
RUN curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/${GLAB_VERSION}/downloads/glab_${GLAB_VERSION#v}_linux_${TARGETARCH}.deb" \
        -o /tmp/glab.deb \
    && apt-get update -qq && apt-get install -y --no-install-recommends /tmp/glab.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/glab.deb

# ---------------------------------------------------------------------------
# DSH home layout — mirrors the VPS unit's Environment=* lines. State that
# the systemd unit pushed into /home/dsh/.dsh/{cache,data,glab-cli} lands in
# the same places here, i.e. inside the ./dsh-config bind mount, whose nested
# .gitignore keeps it out of git.
# ---------------------------------------------------------------------------
ENV HOME=/home/dev \
    XDG_CACHE_HOME=/home/dev/.dsh/cache \
    XDG_DATA_HOME=/home/dev/.dsh/data \
    GLAB_CONFIG_DIR=/home/dev/.dsh/glab-cli \
    UV_CACHE_DIR=/home/dev/.dsh/cache/uv \
    UV_PYTHON_INSTALL_DIR=/home/dev/.dsh/data/uv/python

# ---------------------------------------------------------------------------
# User: dev (UID matches macOS host user — mounted workspace and dsh-config
# files stay owned by the same UID on both sides)
# ---------------------------------------------------------------------------
RUN useradd -m -u ${USER_UID} -s /bin/bash ${USERNAME}

# dsh's agent workspace is the web process cwd, so the whole dev home is the
# workspace: the ./dsh-config mount lands at /home/dev/.dsh and compose mounts
# the host projects dir at /home/dev/workspace. /workspace is kept as a
# symlink so absolute paths written for the old layout still resolve.
RUN ln -sfn /home/dev/workspace /workspace

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
COPY entrypoint.sh /usr/local/bin/dsh-entrypoint
RUN chmod +x /usr/local/bin/dsh-entrypoint

USER ${USERNAME}
WORKDIR /home/dev

ENTRYPOINT ["/usr/local/bin/dsh-entrypoint"]
