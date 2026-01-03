# OpenCode for Unraid - Technical Specification

## Overview

This project creates a Docker container running [OpenCode](https://github.com/anomalyco/opencode) with web UI support, packaged for easy deployment on Unraid servers via a Community Applications XML template.

OpenCode is an open-source AI coding agent that provides a terminal-based interface, desktop app, or web interface for AI-assisted development. This container specifically runs OpenCode in **web mode** (`opencode web`), allowing users to access the AI coding agent from any browser on their network.

## Goals

1. **Web Access**: Run OpenCode in web mode so users can access it from any device on their Unraid server's network
2. **Persistent Configuration**: Store OpenCode config in Unraid's standard appdata location
3. **Development Ready**: Include common development tools (Node.js, Python, npm, git) for AI-assisted coding workflows
4. **Unraid Integration**: Provide a proper Community Applications XML template for easy installation

## Architecture

### Container Structure

```
/
├── config/                     # Mounted: /mnt/user/appdata/opencode
│   ├── opencode.json          # OpenCode configuration
│   ├── auth.json              # Provider API keys (created by opencode auth)
│   ├── agent/                 # Custom agent definitions
│   ├── command/               # Custom commands
│   └── plugin/                # Custom plugins
├── projects/                   # Mounted: User's project directory
├── home/opencode/             # Container user home
└── usr/local/bin/
    └── entrypoint.sh          # Container entrypoint
```

### Network

- **Default Port**: 4096 (OpenCode's default web server port)
- **Hostname**: `0.0.0.0` (listen on all interfaces for network access)
- **Protocol**: HTTP (HTTPS should be handled by reverse proxy if needed)

## Technical Details

### Base Image

Use `node:22-bookworm` as the base image:
- Provides Node.js 22 LTS (required for npm-based opencode-ai installation)
- Debian Bookworm provides stable package ecosystem
- Good balance of size and functionality

### OpenCode Installation

Install via npm globally:
```bash
npm install -g opencode-ai@latest
```

This provides the `opencode` CLI binary with all subcommands including `opencode web`.

### Web Mode Operation

OpenCode web mode (`opencode web`) starts:
1. A headless HTTP server (default port 4096)
2. Serves a web-based terminal UI
3. Provides full OpenCode functionality through the browser

Command structure:
```bash
opencode web --hostname 0.0.0.0 --port 4096
```

### Configuration Directories

OpenCode follows XDG Base Directory specification:

| Purpose | Container Path | Mounted From |
|---------|---------------|--------------|
| Config | `/home/opencode/.config/opencode/` | `/mnt/user/appdata/opencode/config/` |
| Data | `/home/opencode/.local/share/opencode/` | `/mnt/user/appdata/opencode/data/` |
| State | `/home/opencode/.local/state/opencode/` | `/mnt/user/appdata/opencode/state/` |
| Cache | `/home/opencode/.cache/opencode/` | `/mnt/user/appdata/opencode/cache/` |

### Development Tools

The container includes these development tools for AI-assisted coding workflows:

| Tool | Version | Purpose |
|------|---------|---------|
| Node.js | 22.x LTS | JavaScript/TypeScript runtime |
| npm | Latest | Node package manager |
| Python | 3.11+ | Python development |
| pip | Latest | Python package manager |
| git | Latest | Version control |
| curl/wget | Latest | HTTP utilities |
| build-essential | Latest | C/C++ compilation |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | 99 | User ID for file permissions (Unraid nobody) |
| `PGID` | 100 | Group ID for file permissions (Unraid users) |
| `TZ` | `Etc/UTC` | Container timezone |
| `PORT` | 4096 | Web server port |
| `OPENCODE_AUTO_SHARE` | (empty) | Auto-share sessions if set to `true` |
| `OPENCODE_DISABLE_AUTOUPDATE` | (empty) | Disable auto-updates if set to `true` |

### Provider Configuration

Users must configure LLM providers via one of:
1. **Web UI**: Use `/connect` command in OpenCode web interface
2. **Environment variables**: Set provider API keys (e.g., `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`)
3. **Config file**: Edit `/mnt/user/appdata/opencode/config/opencode.json`

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
├── entrypoint.sh             # Container startup script
└── unraid/
    └── opencode.xml          # Unraid Community Apps template
```

## Unraid XML Template

### Required Fields

```xml
<Name>opencode</Name>
<Repository>ghcr.io/USER/opencode-unraid:latest</Repository>
<Network>bridge</Network>
```

### Port Configuration

```xml
<Config 
  Name="WebUI Port" 
  Target="4096" 
  Default="4096" 
  Mode="tcp" 
  Description="OpenCode web interface port" 
  Type="Port" 
  Display="always" 
  Required="true"/>
```

### Volume Mappings

| Name | Container Path | Default Host Path | Mode |
|------|---------------|-------------------|------|
| Config | `/home/opencode/.config/opencode` | `/mnt/user/appdata/opencode/config` | rw |
| Data | `/home/opencode/.local/share/opencode` | `/mnt/user/appdata/opencode/data` | rw |
| State | `/home/opencode/.local/state/opencode` | `/mnt/user/appdata/opencode/state` | rw |
| Cache | `/home/opencode/.cache/opencode` | `/mnt/user/appdata/opencode/cache` | rw |
| Projects | `/projects` | `/mnt/user/projects` | rw |

### Environment Variables in Template

| Name | Variable | Default | Display | Required |
|------|----------|---------|---------|----------|
| PUID | `PUID` | 99 | advanced | false |
| PGID | `PGID` | 100 | advanced | false |
| Timezone | `TZ` | `Etc/UTC` | always | false |
| Port | `PORT` | 4096 | advanced | false |

## Implementation Steps

### Phase 1: Core Container
1. Create Dockerfile with base image and dependencies
2. Install opencode-ai via npm
3. Create entrypoint script for web mode startup
4. Handle user permissions (PUID/PGID)

### Phase 2: Development Environment
1. Add Python and pip
2. Add build tools for native modules
3. Add git for version control
4. Configure proper PATH and environment

### Phase 3: Unraid Integration
1. Create XML template with proper structure
2. Configure volume mappings for persistence
3. Set up port mappings
4. Add WebUI URL pattern

### Phase 4: Testing
1. Build container locally
2. Test web mode access
3. Test persistence across restarts
4. Test on actual Unraid system

## Security Considerations

1. **API Keys**: Stored in persistent volume, not in image
2. **Network Access**: Container binds to all interfaces - use Unraid's firewall/reverse proxy if external access needed
3. **File Permissions**: PUID/PGID ensure proper ownership of persistent files
4. **No Privileged Mode**: Container runs unprivileged

## Future Enhancements

1. **GPU Support**: Add NVIDIA/Intel GPU passthrough for local model inference
2. **SSH Support**: Add SSH server for remote terminal access
3. **Multi-project**: Better project switching/management
4. **Health Checks**: Add Docker health check for monitoring
