# OpenCode for Unraid - Technical Specification

## Overview

This project creates a Docker container running [OpenCode](https://github.com/sst/opencode) (or [Shuvcode](https://github.com/Latitudes-Dev/shuvcode) fork) with headless API server and optional web UI support, packaged for easy deployment on Unraid servers via a Community Applications XML template.

OpenCode is an open-source AI coding agent that provides a terminal-based interface, desktop app, or web interface for AI-assisted development. This container runs in **headless serve mode** by default (`opencode serve`), allowing remote clients to connect. Optionally, a **web UI** can be enabled on a separate port.

## Goals

1. **Headless Server**: Run OpenCode in serve mode for remote client connections
2. **Optional Web UI**: Enable built-in web interface on separate port when needed
3. **CLI Flexibility**: Support both mainline OpenCode and Shuvcode fork
4. **Persistent Configuration**: Store config in Unraid's standard appdata location
5. **Development Ready**: Include common development tools (Node.js, Python, npm, git)
6. **Unraid Integration**: Provide a proper Community Applications XML template
7. **Extensible**: Allow users to install additional packages at runtime
8. **Self-Updating**: Automatically update when safe (no active sessions)

## Architecture

### Container Structure

```
/
├── home/opencode/
│   ├── .config/opencode/       # Mounted: /mnt/user/appdata/opencode/config
│   │   ├── opencode.json       # Configuration
│   │   ├── auth.json           # Provider API keys (created by opencode auth)
│   │   ├── agent/              # Custom agent definitions
│   │   ├── command/            # Custom commands
│   │   └── plugin/             # Custom plugins
│   ├── .local/share/opencode/  # Mounted: /mnt/user/appdata/opencode/data
│   ├── .local/state/opencode/  # Mounted: /mnt/user/appdata/opencode/state
│   ├── .cache/opencode/        # Mounted: /mnt/user/appdata/opencode/cache
│   └── .ssh/                   # Mounted: /mnt/user/appdata/opencode/ssh
├── projects/                   # Mounted: User's project directory
└── usr/local/bin/
    ├── entrypoint.sh           # Container entrypoint
    └── update-checker.sh       # Background update service
```

### Network

- **API Port (default)**: 4096 - Headless API server for remote clients
- **Web Port (optional)**: 4097 - Web UI when ENABLE_WEB_UI=true
- **Hostname**: `0.0.0.0` (listen on all interfaces for network access)
- **Protocol**: HTTP (HTTPS should be handled by reverse proxy if needed)

## Technical Details

### Base Image

Use `node:22-bookworm` as the base image:
- Provides Node.js 22 LTS (required for npm-based installation)
- Debian Bookworm provides stable package ecosystem
- Good balance of size and functionality
- NOT alpine - dev tools need glibc, native modules fail on musl

### CLI Installation

Install both CLIs via npm globally:
```bash
npm install -g opencode-ai@latest shuvcode@latest
```

This provides both `opencode` and `shuvcode` CLI binaries, selectable via `OPENCODE_CLI` env var.

### Dual Mode Operation

**Primary (always running)**: Headless API server
```bash
${OPENCODE_CLI} serve --hostname 0.0.0.0 --port ${PORT}
```

**Secondary (optional)**: Web UI on separate port
```bash
${OPENCODE_CLI} web --hostname 0.0.0.0 --port ${WEB_PORT}
```

The web UI is enabled when `ENABLE_WEB_UI=true`. Both modes can run simultaneously on different ports.

### Configuration Directories

OpenCode follows XDG Base Directory specification:

| Purpose | Container Path | Mounted From |
|---------|---------------|--------------|
| Config | `/home/opencode/.config/opencode/` | `/mnt/user/appdata/opencode/config/` |
| Data | `/home/opencode/.local/share/opencode/` | `/mnt/user/appdata/opencode/data/` |
| State | `/home/opencode/.local/state/opencode/` | `/mnt/user/appdata/opencode/state/` |
| Cache | `/home/opencode/.cache/opencode/` | `/mnt/user/appdata/opencode/cache/` |
| SSH | `/home/opencode/.ssh/` | `/mnt/user/appdata/opencode/ssh/` |

### Development Tools

The container includes these development tools for AI-assisted coding workflows:

| Tool | Version | Purpose |
|------|---------|---------|
| Node.js | 22.x LTS | JavaScript/TypeScript runtime |
| npm | Latest | Node package manager |
| Python | 3.11+ | Python development |
| pip | Latest | Python package manager |
| git | Latest | Version control |
| git-lfs | Latest | Large file support |
| curl/wget | Latest | HTTP utilities |
| build-essential | Latest | C/C++ compilation |
| ripgrep | Latest | Fast text search |
| fd | Latest | Fast file finder |
| jq | Latest | JSON processor |
| ssh-client | Latest | Git SSH operations |
| htop | Latest | Process monitoring |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | 99 | User ID for file permissions (Unraid nobody) |
| `PGID` | 100 | Group ID for file permissions (Unraid users) |
| `TZ` | `Etc/UTC` | Container timezone |
| `PORT` | 4096 | Headless API server port |
| `WEB_PORT` | 4097 | Web UI port (when enabled) |
| `ENABLE_WEB_UI` | false | Enable web UI on WEB_PORT |
| `OPENCODE_CLI` | shuvcode | CLI to use: `opencode` or `shuvcode` |
| `EXTRA_APT_PACKAGES` | (empty) | Space-separated apt packages to install |
| `EXTRA_NPM_PACKAGES` | (empty) | Space-separated npm global packages to install |
| `EXTRA_PIP_PACKAGES` | (empty) | Space-separated pip packages to install |
| `UPDATE_CHECK_INTERVAL` | 3600 | Seconds between update checks (1 hour) |
| `OPENCODE_DISABLE_AUTOUPDATE` | (empty) | Disable auto-updates if set to `true` |
| `SHUVCODE_DESKTOP_URL` | `https://app.opencode.ai` | Desktop UI URL for web mode |

### Custom Package Installation

The entrypoint script supports installing additional packages at runtime:

```bash
EXTRA_APT_PACKAGES="golang ruby lua5.4"
EXTRA_NPM_PACKAGES="typescript tsx pnpm"
EXTRA_PIP_PACKAGES="black ruff mypy"
```

Packages are installed on every container start. For performance, consider building a custom image for frequently used packages.

### Auto-Update System

The container includes a background update checker (`update-checker.sh`) that:

1. Periodically checks for new versions via `npm view ${OPENCODE_CLI} version`
2. Compares against installed version
3. Checks for active sessions via `GET /session/status` API
4. If no active sessions, installs update and sends SIGTERM for graceful restart
5. If sessions active, postpones update to next check interval

The update checker respects:
- `OPENCODE_DISABLE_AUTOUPDATE=true` - Disables the checker entirely
- `UPDATE_CHECK_INTERVAL` - Adjusts check frequency (default 3600 seconds)

### Session Detection API

OpenCode exposes session management endpoints:

| Endpoint | Purpose |
|----------|---------|
| `GET /global/health` | Health check (returns `{"healthy": true}`) |
| `GET /session` | List all sessions |
| `GET /session/status` | Get status of all sessions |
| `GET /session/:id` | Get specific session details |

The update checker uses `/session/status` to determine if users are actively connected before triggering updates.

### Provider Configuration

Users must configure LLM providers via one of:
1. **Desktop App/CLI**: Connect to server and use `/connect` command
2. **Web UI**: Use `/connect` command in browser
3. **Environment variables**: Set provider API keys (e.g., `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`)
4. **Config file**: Edit `/mnt/user/appdata/opencode/config/opencode.json`

Supported providers include:
- Anthropic (Claude)
- OpenAI
- Google (Gemini)
- Azure OpenAI
- Groq
- Cerebras
- Local models (Ollama, LM Studio)

## File Structure

```
opencode_unraid/
├── SPEC.md                    # This specification
├── README.md                  # User documentation
├── AGENTS.md                  # Agent development guidelines
├── Dockerfile                 # Container build instructions
├── docker-compose.yml         # Local development/testing
├── entrypoint.sh              # Container startup script
├── scripts/
│   └── update-checker.sh      # Background update service
└── unraid/
    └── opencode.xml           # Unraid Community Apps template
```

## Unraid XML Template

### Required Fields

```xml
<Name>opencode</Name>
<Repository>ghcr.io/thesammykins/opencode-unraid:latest</Repository>
<Network>bridge</Network>
```

### Port Configuration

```xml
<Config 
  Name="API Server Port" 
  Target="4096" 
  Default="4096" 
  Mode="tcp" 
  Description="Headless API server port" 
  Type="Port" 
  Display="always" 
  Required="true"/>

<Config 
  Name="Web UI Port" 
  Target="4097" 
  Default="4097" 
  Mode="tcp" 
  Description="Optional web UI port" 
  Type="Port" 
  Display="always" 
  Required="false"/>
```

### Volume Mappings

| Name | Container Path | Default Host Path | Mode |
|------|---------------|-------------------|------|
| Config | `/home/opencode/.config/opencode` | `/mnt/user/appdata/opencode/config` | rw |
| Data | `/home/opencode/.local/share/opencode` | `/mnt/user/appdata/opencode/data` | rw |
| State | `/home/opencode/.local/state/opencode` | `/mnt/user/appdata/opencode/state` | rw |
| Cache | `/home/opencode/.cache/opencode` | `/mnt/user/appdata/opencode/cache` | rw |
| SSH | `/home/opencode/.ssh` | `/mnt/user/appdata/opencode/ssh` | rw |
| Projects | `/projects` | `/mnt/user/projects` | rw |

## Implementation Status

### Phase 1: Core Container
1. ✅ Create Dockerfile with base image and dependencies
2. ✅ Install opencode and shuvcode via npm
3. ✅ Create entrypoint script with dual-mode support
4. ✅ Handle user permissions (PUID/PGID)
5. ✅ Implement CLI selection (OPENCODE_CLI)

### Phase 2: Development Environment
1. ✅ Add Python and pip
2. ✅ Add build tools for native modules
3. ✅ Add git with LFS support
4. ✅ Add SSH client for git operations
5. ✅ Configure proper PATH and environment

### Phase 3: Extensibility
1. ✅ Implement EXTRA_APT_PACKAGES support
2. ✅ Implement EXTRA_NPM_PACKAGES support
3. ✅ Implement EXTRA_PIP_PACKAGES support
4. ✅ Create update-checker.sh for auto-updates
5. ✅ Implement session-aware update logic

### Phase 4: Unraid Integration
1. ✅ Create XML template with proper structure
2. ✅ Configure volume mappings for persistence
3. ✅ Set up dual port mappings
4. ✅ Add WebUI URL pattern
5. ✅ Add all environment variables including CLI selection

### Phase 5: Testing
1. ✅ Build container locally
2. ✅ Test serve mode access
3. ✅ Test dual-mode (serve + web)
4. ✅ Test CLI switching (opencode vs shuvcode)
5. Test persistence across restarts
6. Test custom package installation
7. Test auto-update with session detection
8. Test on actual Unraid system

## Security Considerations

1. **API Keys**: Stored in persistent volume, not in image
2. **Network Access**: Container binds to all interfaces - use Unraid's firewall/reverse proxy if external access needed
3. **File Permissions**: PUID/PGID ensure proper ownership of persistent files
4. **No Privileged Mode**: Container runs unprivileged
5. **SSH Keys**: Mounted volume with proper permissions (700 for .ssh, 600 for keys)

## Future Enhancements

1. **GPU Support**: Add NVIDIA/Intel GPU passthrough for local model inference
2. **Multi-project**: Better project switching/management
3. **Backup Integration**: Automated backup of sessions and config
4. **Metrics**: Prometheus endpoint for monitoring
