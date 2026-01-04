# OpenCode/Shuvcode for Unraid
# AI-powered coding agent with headless server and optional web interface
# Supports both opencode-ai (mainline) and shuvcode (enhanced fork)

FROM node:22-bookworm

LABEL maintainer="OpenCode Unraid"
LABEL org.opencontainers.image.source="https://github.com/thesammykins/opencode-unraid"
LABEL org.opencontainers.image.description="OpenCode/Shuvcode AI coding agent for Unraid with headless server and optional web UI"
LABEL org.opencontainers.image.licenses="MIT"

# Environment defaults
ENV PUID=99 \
    PGID=100 \
    TZ=Etc/UTC \
    PORT=4096 \
    WEB_PORT=4097 \
    ENABLE_WEB_UI=false \
    OPENCODE_CLI=shuvcode \
    HOME=/home/opencode \
    XDG_CONFIG_HOME=/home/opencode/.config \
    XDG_DATA_HOME=/home/opencode/.local/share \
    XDG_STATE_HOME=/home/opencode/.local/state \
    XDG_CACHE_HOME=/home/opencode/.cache \
    UPDATE_CHECK_INTERVAL=3600 \
    SHUVCODE_DESKTOP_URL=https://app.opencode.ai

# Install system dependencies and development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    git \
    git-lfs \
    curl \
    wget \
    tini \
    gosu \
    jq \
    ripgrep \
    fd-find \
    tree \
    vim-tiny \
    less \
    inotify-tools \
    tzdata \
    ca-certificates \
    openssh-client \
    gnupg \
    unzip \
    zip \
    xz-utils \
    procps \
    htop \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -u 99 -g users -m -d /home/opencode -s /bin/bash opencode

RUN mkdir -p \
    /home/opencode/.config/opencode \
    /home/opencode/.local/share/opencode \
    /home/opencode/.local/state/opencode \
    /home/opencode/.cache/opencode \
    /home/opencode/.ssh \
    /projects && \
    chown -R opencode:users /home/opencode /projects && \
    chmod 700 /home/opencode/.ssh

# Install both opencode-ai and shuvcode so user can switch between them
RUN npm install -g opencode-ai@latest shuvcode@latest && \
    npm cache clean --force

RUN ln -s /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 scripts/update-checker.sh /usr/local/bin/update-checker.sh

WORKDIR /projects

# Expose both API server port and optional web UI port
EXPOSE 4096 4097

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/global/health || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

# Default: headless serve mode (no CMD args - entrypoint handles it)
CMD []
