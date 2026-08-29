# devbox — dev container for the pi agent + Claude Code + Meridian
# Base: Ubuntu 24.04 LTS, arm64/amd64

FROM ubuntu:24.04

ARG USERNAME=dev
ARG USER_UID=501
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Base packages
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl wget git build-essential unzip jq python3 \
        openssh-server tmux ripgrep fd-find fzf gh \
        openjdk-21-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

# fd-find installs as `fdfind`; LazyVim/telescope expect `fd`
RUN ln -s /usr/bin/fdfind /usr/local/bin/fd

# lazygit: not packaged in Ubuntu 24.04 — install the official static binary
ARG LAZYGIT_VERSION=v0.64.1
RUN curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION#v}_Linux_arm64.tar.gz" \
        -o /tmp/lazygit.tar.gz \
    && tar -xzf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit \
    && rm /tmp/lazygit.tar.gz

# ---------------------------------------------------------------------------
# Node.js 22 LTS (for pi, Claude Code, Meridian — all npm globals)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Neovim (pinned release tarball — apt version is too old for LazyVim)
# ---------------------------------------------------------------------------
ARG NVIM_VERSION=v0.12.5
RUN curl -fsSL "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-arm64.tar.gz" \
        -o /tmp/nvim.tar.gz \
    && tar -xzf /tmp/nvim.tar.gz -C /opt \
    && ln -s /opt/nvim-linux-arm64/bin/nvim /usr/local/bin/nvim \
    && rm /tmp/nvim.tar.gz

# ---------------------------------------------------------------------------
# Agent tools (npm globals)
# ---------------------------------------------------------------------------
# pi installs with --ignore-scripts (its README requires it);
# claude-code and meridian MUST run their postinstalls (native binary).
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent
RUN npm install -g @anthropic-ai/claude-code @rynfar/meridian

# ---------------------------------------------------------------------------
# User: dev (UID matches macOS host user — mounted workspace files stay owned
# by the same UID on both sides)
# ---------------------------------------------------------------------------
RUN useradd -m -u ${USER_UID} -s /bin/bash ${USERNAME}

# SSH host keys baked at build time (rootfs is read-only at runtime)
RUN ssh-keygen -A

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
