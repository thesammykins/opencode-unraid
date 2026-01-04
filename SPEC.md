# Shuvcode for Unraid - Technical Specification

## Overview

This project creates a Docker container running [Shuvcode](https://github.com/Latitudes-Dev/shuvcode) (enhanced OpenCode fork) with web UI support, packaged for easy deployment on Unraid servers via a Community Applications XML template.

Shuvcode is an enhanced fork of OpenCode - an open-source AI coding agent that provides a terminal-based interface, desktop app, or web interface for AI-assisted development. This container specifically runs Shuvcode in **web mode** (`opencode web`), allowing users to access the AI coding agent from any browser on their network.

## Goals

1. **Web Access**: Run Shuvcode in web mode so users can access it from any device on their Unraid server's network
2. **Persistent Configuration**: Store Shuvcode config in Unraid's standard appdata location
3. **Development Ready**: Include common development tools (Node.js, Python, npm, git) for AI-assisted coding workflows
4. **Unraid Integration**: Provide a proper Community Applications XML template for easy installation
5. **Extensible**: Allow users to install additional packages at runtime
6. **Self-Updating**: Automatically update Shuvcode when safe (no active sessions)

## Architecture

### Container Structure

```
/
├── home/opencode/
│   ├── .config/opencode/       # Mounted: /mnt/user/appdata/shuvcode/config
│   │   ├── opencode.json       # Shuvcode configuration
│   │   ├── auth.json           # Provider API keys (created by opencode auth)
│   │   ├── agent/              # Custom agent definitions
│   │   ├── command/            # Custom commands
│   │   └── plugin/             # Custom plugins
│   ├── .local/share/opencode/  # Mounted: /mnt/user/appdata/shuvcode/data
│   ├── .local/state/opencode/  # Mounted: /mnt/user/appdata/shuvcode/state
│   ├── .cache/opencode/        # Mounted: /mnt/user/appdata/shuvcode/cache
│   └── .ssh/                   # Mounted: /mnt/user/appdata/shuvcode/ssh
├── projects/                   # Mounted: User's project directory
└── usr/local/bin/
    ├── entrypoint.sh           # Container entrypoint
    └── update-checker.sh       # Background update service
```

### Network

- **Default Port**: 4096 (Shuvcode's default web server port)
- **Hostname**: `0.0.0.0` (listen on all interfaces for network access)
- **Protocol**: HTTP (HTTPS should be handled by reverse proxy if needed)

## Technical Details

### Base Image

Use `node:22-bookworm` as the base image:
- Provides Node.js 22 LTS (required for npm-based shuvcode installation)
- Debian Bookworm provides stable package ecosystem
- Good balance of size and functionality
- NOT alpine - dev tools need glibc, native modules fail on musl

### Shuvcode Installation

Install via npm globally:
```bash
npm install -g shuvcode@latest
```

This provides the `opencode` CLI binary with all subcommands including `opencode web`.

### Web Mode Operation

Shuvcode web mode (`opencode web`) starts:
1. A headless HTTP server (default port 4096)
2. Serves a web-based terminal UI
3. Provides full Shuvcode functionality through the browser
4. Exposes REST API at `/doc` (OpenAPI 3.1 spec)
5. Real-time updates via SSE at `/event`

Command structure:
```bash
opencode web --hostname 0.0.0.0 --port 4096
```

### Configuration Directories

Shuvcode follows XDG Base Directory specification:

| Purpose | Container Path | Mounted From |
|---------|---------------|--------------|
| Config | `/home/opencode/.config/opencode/` | `/mnt/user/appdata/shuvcode/config/` |
| Data | `/home/opencode/.local/share/opencode/` | `/mnt/user/appdata/shuvcode/data/` |
| State | `/home/opencode/.local/state/opencode/` | `/mnt/user/appdata/shuvcode/state/` |
| Cache | `/home/opencode/.cache/opencode/` | `/mnt/user/appdata/shuvcode/cache/` |
| SSH | `/home/opencode/.ssh/` | `/mnt/user/appdata/shuvcode/ssh/` |

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
| `PORT` | 4096 | Web server port |
| `EXTRA_APT_PACKAGES` | (empty) | Space-separated apt packages to install |
| `EXTRA_NPM_PACKAGES` | (empty) | Space-separated npm global packages to install |
| `EXTRA_PIP_PACKAGES` | (empty) | Space-separated pip packages to install |
| `UPDATE_CHECK_INTERVAL` | 3600 | Seconds between update checks (1 hour) |
| `OPENCODE_DISABLE_AUTOUPDATE` | (empty) | Disable auto-updates if set to `true` |
| `OPENCODE_DISABLE_LSP_DOWNLOAD` | (empty) | Disable LSP auto-download if set to `true` |

### Custom Package Installation

The entrypoint script supports installing additional packages at runtime:

```bash
# APT packages (system-level)
EXTRA_APT_PACKAGES="golang ruby lua5.4"

# NPM packages (installed globally)
EXTRA_NPM_PACKAGES="typescript tsx pnpm"

# PIP packages (installed system-wide)
EXTRA_PIP_PACKAGES="black ruff mypy"
```

Packages are installed on every container start. For performance, consider building a custom image for frequently used packages.

### Auto-Update System

The container includes a background update checker (`update-checker.sh`) that:

1. Periodically checks for new versions via `npm view shuvcode version`
2. Compares against installed version
3. Checks for active sessions via `GET /session/status` API
4. If no active sessions, installs update and sends SIGTERM for graceful restart
5. If sessions active, postpones update to next check interval

The update checker respects:
- `OPENCODE_DISABLE_AUTOUPDATE=true` - Disables the checker entirely
- `UPDATE_CHECK_INTERVAL` - Adjusts check frequency (default 3600 seconds)

### Session Detection API

Shuvcode exposes session management endpoints:

| Endpoint | Purpose |
|----------|---------|
| `GET /global/health` | Health check (returns `{"healthy": true}`) |
| `GET /session` | List all sessions |
| `GET /session/status` | Get status of all sessions |
| `GET /session/:id` | Get specific session details |

The update checker uses `/session/status` to determine if users are actively connected before triggering updates.

### Provider Configuration

Users must configure LLM providers via one of:
1. **Web UI**: Use `/connect` command in Shuvcode web interface
2. **Environment variables**: Set provider API keys (e.g., `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`)
3. **Config file**: Edit `/mnt/user/appdata/shuvcode/config/opencode.json`

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
<Name>shuvcode</Name>
<Repository>ghcr.io/thesammykins/opencode-unraid:latest</Repository>
<Network>bridge</Network>
```

### Port Configuration

```xml
<Config 
  Name="WebUI Port" 
  Target="4096" 
  Default="4096" 
  Mode="tcp" 
  Description="Shuvcode web interface port" 
  Type="Port" 
  Display="always" 
  Required="true"/>
```

### Volume Mappings

| Name | Container Path | Default Host Path | Mode |
|------|---------------|-------------------|------|
| Config | `/home/opencode/.config/opencode` | `/mnt/user/appdata/shuvcode/config` | rw |
| Data | `/home/opencode/.local/share/opencode` | `/mnt/user/appdata/shuvcode/data` | rw |
| State | `/home/opencode/.local/state/opencode` | `/mnt/user/appdata/shuvcode/state` | rw |
| Cache | `/home/opencode/.cache/opencode` | `/mnt/user/appdata/shuvcode/cache` | rw |
| SSH | `/home/opencode/.ssh` | `/mnt/user/appdata/shuvcode/ssh` | rw |
| Projects | `/projects` | `/mnt/user/projects` | rw |

### Environment Variables in Template

| Name | Variable | Default | Display | Required |
|------|----------|---------|---------|----------|
| PUID | `PUID` | 99 | advanced | false |
| PGID | `PGID` | 100 | advanced | false |
| Timezone | `TZ` | `Etc/UTC` | always | false |
| Port | `PORT` | 4096 | advanced | false |
| Extra APT | `EXTRA_APT_PACKAGES` | (empty) | advanced | false |
| Extra NPM | `EXTRA_NPM_PACKAGES` | (empty) | advanced | false |
| Extra PIP | `EXTRA_PIP_PACKAGES` | (empty) | advanced | false |
| Update Interval | `UPDATE_CHECK_INTERVAL` | 3600 | advanced | false |

## Implementation Steps

### Phase 1: Core Container
1. ✅ Create Dockerfile with base image and dependencies
2. ✅ Install shuvcode via npm
3. ✅ Create entrypoint script for web mode startup
4. ✅ Handle user permissions (PUID/PGID)

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
3. ✅ Set up port mappings
4. ✅ Add WebUI URL pattern
5. ✅ Add all environment variables

### Phase 5: Testing
1. Build container locally
2. Test web mode access
3. Test persistence across restarts
4. Test custom package installation
5. Test auto-update with session detection
6. Test on actual Unraid system

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
