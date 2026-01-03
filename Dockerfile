# OpenCode for Unraid
# AI-powered coding agent with web interface
# https://github.com/anomalyco/opencode

FROM node:22-bookworm

LABEL maintainer="OpenCode Unraid"
LABEL org.opencontainers.image.source="https://github.com/anomalyco/opencode"
LABEL org.opencontainers.image.description="OpenCode AI coding agent for Unraid with web interface"
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
    XDG_CACHE_HOME=/home/opencode/.cache

# Install system dependencies and development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Python and pip
    python3 \
    python3-pip \
    python3-venv \
    # Build tools for native modules
    build-essential \
    # Version control
    git \
    # HTTP utilities
    curl \
    wget \
    tini \
    gosu \
    # Additional useful tools
    jq \
    ripgrep \
    fd-find \
    tree \
    vim-tiny \
    less \
    # For file watching
    inotify-tools \
    # Timezone support
    tzdata \
    # CA certificates for HTTPS
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create opencode user
RUN groupadd -g ${PGID} opencode && \
    useradd -u ${PUID} -g opencode -m -d /home/opencode -s /bin/bash opencode

# Create directory structure
RUN mkdir -p \
    /home/opencode/.config/opencode \
    /home/opencode/.local/share/opencode \
    /home/opencode/.local/state/opencode \
    /home/opencode/.cache/opencode \
    /projects && \
    chown -R opencode:opencode /home/opencode /projects

# Install opencode-ai globally
RUN npm install -g opencode-ai@latest && \
    npm cache clean --force

# Create symlink for fd (Debian names it fd-find)
RUN ln -s /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null || true

# Copy entrypoint script
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# Working directory
WORKDIR /projects

# Expose web UI port
EXPOSE 4096

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/global/health || exit 1

# Use tini as init system
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

# Default command - run opencode in web mode
CMD ["opencode", "web"]
