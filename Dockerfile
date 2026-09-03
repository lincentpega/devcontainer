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
        python3-pip python3-venv \
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
# Node.js 24 LTS (for pi, Claude Code, Meridian — all npm globals)
# ---------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
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
# Official Tavily CLI (tvly) — live web search for the agent
# ---------------------------------------------------------------------------
# Installed from the official PyPI package (tavily-cli -> tvly) into an
# isolated venv under /opt (rootfs is read-only at runtime; the venv is
# world-readable and the launcher lands in /usr/local/bin so the non-root
# `dev` user gets tvly on PATH). No third-party installers — everything via
# apt/pip. Auth state (~/.tavily) lives on the devbox-home volume and survives
# rebuilds: authenticate once with `tvly login` (browser OAuth) or
# `tvly login --api-key`.
RUN python3 -m venv /opt/tavily \
    && /opt/tavily/bin/pip install --no-cache-dir tavily-cli \
    && ln -s /opt/tavily/bin/tvly /usr/local/bin/tvly

# ---------------------------------------------------------------------------
# uv (Python package manager / PEP 723 script runner) — the web-fetch skill's
# fetch.py runs via `uv run`. Image-baked so skills can rely on it at runtime
# (rootfs is read-only; ~/.local would be lost on `down -v`).
# ---------------------------------------------------------------------------
RUN python3 -m venv /opt/uv \
    && /opt/uv/bin/pip install --no-cache-dir uv \
    && ln -s /opt/uv/bin/uv /usr/local/bin/uv

# ---------------------------------------------------------------------------
# glab (GitLab CLI) — deb package, pinned; TARGETARCH-aware (arm64/amd64)
# ---------------------------------------------------------------------------
ARG GLAB_VERSION=v1.115.0
ARG TARGETARCH
RUN curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/${GLAB_VERSION}/downloads/glab_${GLAB_VERSION#v}_linux_${TARGETARCH}.deb" \
        -o /tmp/glab.deb \
    && apt-get update -qq && apt-get install -y --no-install-recommends /tmp/glab.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/glab.deb

# ---------------------------------------------------------------------------
# Docker CLI + compose plugin — CLIENT only, pinned to engine 28.x to match the
# docker-dind sidecar (see compose.yml). devbox itself stays locked down: no
# docker.sock, no extra caps — everything talks to the sidecar over the compose
# network via DOCKER_HOST=tcp://docker-dind:2375.
# ---------------------------------------------------------------------------
ARG DOCKER_VERSION=28.0.1
ARG TARGETARCH
RUN ARCH=$([ "${TARGETARCH}" = "arm64" ] && echo aarch64 || echo x86_64) \
    && curl -fsSL "https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VERSION}.tgz" \
        -o /tmp/docker.tgz \
    && tar -xzf /tmp/docker.tgz -C /tmp \
    && install -m 0755 /tmp/docker/docker /usr/local/bin/docker \
    && rm -rf /tmp/docker /tmp/docker.tgz

# docker compose plugin — for ad-hoc `docker compose` runs of the repo's
# docker-compose-local.yml files against the sidecar daemon. Latest stable
# release; failure-tolerant so a transient GitHub hiccup never breaks a rebuild.
RUN ARCH=$([ "${TARGETARCH}" = "arm64" ] && echo aarch64 || echo x86_64) \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && if COMPOSE_TAG=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name) \
        && curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_TAG}/docker-compose-linux-${ARCH}" \
            -o /usr/local/lib/docker/cli-plugins/docker-compose; then \
        chmod 0755 /usr/local/lib/docker/cli-plugins/docker-compose; \
        echo "[build] docker compose plugin ${COMPOSE_TAG} installed"; \
    else \
        echo "WARN: docker compose plugin fetch failed — continuing without it" >&2; \
    fi

# ---------------------------------------------------------------------------
# JDK 25 (Temurin) — default java/javac. The Java services compile with
# --release 25, which the apt JDK 21 (installed above) cannot do, and Ubuntu
# 24.04 has no openjdk-25 package, so Temurin is baked into /opt and
# registered via update-alternatives at higher priority — `java`/`javac`
# resolve to 25 while JDK 21 stays installed as a fallback. JDK25_PATH is an
# Adoptium API path segment: default resolves to the newest 25 GA on each
# rebuild; pin by replacing with e.g. `version/25.0.4%2B1` (URL-encode +).
# ---------------------------------------------------------------------------
ARG JDK25_PATH=latest/25/ga
ARG TARGETARCH
RUN ARCH=$([ "${TARGETARCH}" = "arm64" ] && echo aarch64 || echo x64) \
    && mkdir -p /opt/jdk-25 \
    && curl -fsSL "https://api.adoptium.net/v3/binary/${JDK25_PATH}/linux/${ARCH}/jdk/hotspot/normal/eclipse" \
        | tar -xz --strip-components=1 -C /opt/jdk-25 \
    && update-alternatives --install /usr/bin/java java /opt/jdk-25/bin/java 2500 \
        --slave /usr/bin/javac javac /opt/jdk-25/bin/javac \
        --slave /usr/bin/jar jar /opt/jdk-25/bin/jar \
        --slave /usr/bin/javap javap /opt/jdk-25/bin/javap \
        --slave /usr/bin/jshell jshell /opt/jdk-25/bin/jshell \
        --slave /usr/bin/keytool keytool /opt/jdk-25/bin/keytool \
    && rm -rf /opt/jdk-25/man

# ---------------------------------------------------------------------------
# Ghostty terminfo (TERM=xterm-ghostty) — compiled via tic, for any terminal
# ---------------------------------------------------------------------------
COPY config/terminfo/ /usr/share/terminfo/

# ---------------------------------------------------------------------------
# User: dev (UID matches macOS host user — mounted workspace files stay owned
# by the same UID on both sides)
# ---------------------------------------------------------------------------
RUN useradd -m -u ${USER_UID} -s /bin/bash ${USERNAME}

# SSH host keys baked at build time (rootfs is read-only at runtime)
RUN ssh-keygen -A

# Public-key auth only. `dev` has no password, so a password prompt can never
# succeed — refuse the attempt outright instead of hiding a missing
# /auth/authorized_keys behind an unanswerable prompt.
RUN printf '%s\n' \
        'PasswordAuthentication no' \
        'KbdInteractiveAuthentication no' \
        'PermitRootLogin no' \
        > /etc/ssh/sshd_config.d/devbox.conf

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
