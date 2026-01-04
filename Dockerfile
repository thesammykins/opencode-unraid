# Shuvcode for Unraid
# AI-powered coding agent with web interface (enhanced fork)
# https://github.com/Latitudes-Dev/shuvcode

FROM node:22-bookworm

LABEL maintainer="Shuvcode Unraid"
LABEL org.opencontainers.image.source="https://github.com/Latitudes-Dev/shuvcode"
LABEL org.opencontainers.image.description="Shuvcode AI coding agent for Unraid with web interface"
LABEL org.opencontainers.image.licenses="MIT"

# Environment defaults
ENV PUID=99 \
    PGID=100 \
    TZ=Etc/UTC \
    PORT=4096 \
    HOME=/home/opencode \
    XDG_CONFIG_HOME=/home/opencode/.config \
    XDG_DATA_HOME=/home/opencode/.local/share \
    XDG_STATE_HOME=/home/opencode/.local/state \
    XDG_CACHE_HOME=/home/opencode/.cache \
    UPDATE_CHECK_INTERVAL=3600

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

RUN npm install -g shuvcode@latest && \
    npm cache clean --force

RUN ln -s /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 scripts/update-checker.sh /usr/local/bin/update-checker.sh

WORKDIR /projects

EXPOSE 4096

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/global/health || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

CMD ["shuvcode", "web"]
