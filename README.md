# OpenCode for Unraid

Docker container running [OpenCode](https://github.com/sst/opencode) (or [Shuvcode](https://github.com/Latitudes-Dev/shuvcode) fork) as a headless API server for AI-assisted development, designed for Unraid servers.

OpenCode is an open-source AI coding agent that helps you write, debug, and refactor code using LLMs from a variety of providers. This container runs in **headless serve mode** by default, allowing other OpenCode clients (desktop app, CLI, web) to connect to it remotely.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Unraid Server                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              OpenCode Container                          ││
│  │  ┌─────────────────┐  ┌─────────────────┐               ││
│  │  │  Headless API   │  │  Web UI (opt)   │               ││
│  │  │  Port 4096      │  │  Port 4097      │               ││
│  │  └────────┬────────┘  └────────┬────────┘               ││
│  └───────────┼────────────────────┼─────────────────────────┘│
└──────────────┼────────────────────┼──────────────────────────┘
               │                    │
    ┌──────────┴──────────┐   ┌─────┴─────┐
    │  Desktop App/CLI    │   │  Browser  │
    │  (any device)       │   │  (opt)    │
    └─────────────────────┘   └───────────┘
```

## Features

- **Headless API server** - Connect from OpenCode desktop app, CLI, or any client
- **Optional web UI** - Enable built-in web interface on separate port
- **CLI choice** - Switch between mainline `opencode` or `shuvcode` fork
- **Development ready** - Includes Node.js, Python, npm, git, and build tools
- **Persistent configuration** - Config and sessions stored in Unraid appdata
- **Multi-provider support** - Works with Anthropic, OpenAI, Google, Azure, Groq, and local models
- **Auto-updates** - Automatically updates when no sessions are active
- **Custom packages** - Install additional apt, npm, or pip packages at runtime
- **SSH support** - Mount SSH keys for git operations

## Quick Start

### Unraid Community Applications

1. Search for "OpenCode" in Community Applications
2. Click Install
3. Configure the paths and ports
4. Start the container
5. Connect using the OpenCode desktop app or enable the web UI

### Docker Compose

```yaml
version: "3.8"

services:
  opencode:
    image: ghcr.io/thesammykins/opencode-unraid:latest
    container_name: opencode
    ports:
      - "4096:4096"  # Headless API server
      - "4097:4097"  # Optional web UI
    volumes:
      - ./appdata/config:/home/opencode/.config/opencode
      - ./appdata/data:/home/opencode/.local/share/opencode
      - ./appdata/state:/home/opencode/.local/state/opencode
      - ./appdata/cache:/home/opencode/.cache/opencode
      - ./appdata/ssh:/home/opencode/.ssh
      - /path/to/projects:/projects
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - OPENCODE_CLI=shuvcode      # or 'opencode' for mainline
      - ENABLE_WEB_UI=false        # set to 'true' to enable web UI
    restart: unless-stopped
```

### Docker CLI

```bash
docker run -d \
  --name opencode \
  -p 4096:4096 \
  -p 4097:4097 \
  -v /mnt/user/appdata/opencode/config:/home/opencode/.config/opencode \
  -v /mnt/user/appdata/opencode/data:/home/opencode/.local/share/opencode \
  -v /mnt/user/appdata/opencode/state:/home/opencode/.local/state/opencode \
  -v /mnt/user/appdata/opencode/cache:/home/opencode/.cache/opencode \
  -v /mnt/user/appdata/opencode/ssh:/home/opencode/.ssh \
  -v /mnt/user/projects:/projects \
  -e PUID=99 \
  -e PGID=100 \
  -e TZ=Etc/UTC \
  -e OPENCODE_CLI=shuvcode \
  ghcr.io/thesammykins/opencode-unraid:latest
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | 99 | User ID for file permissions |
| `PGID` | 100 | Group ID for file permissions |
| `TZ` | `Etc/UTC` | Container timezone |
| `PORT` | 4096 | Headless API server port |
| `WEB_PORT` | 4097 | Web UI port (when enabled) |
| `ENABLE_WEB_UI` | `false` | Enable built-in web UI on WEB_PORT |
| `OPENCODE_CLI` | `shuvcode` | CLI to use: `opencode` (mainline) or `shuvcode` (fork) |
| `EXTRA_APT_PACKAGES` | - | Space-separated apt packages to install |
| `EXTRA_NPM_PACKAGES` | - | Space-separated npm packages to install globally |
| `EXTRA_PIP_PACKAGES` | - | Space-separated pip packages to install |
| `UPDATE_CHECK_INTERVAL` | 3600 | Seconds between update checks |
| `OPENCODE_DISABLE_AUTOUPDATE` | - | Set to `true` to disable auto-updates |
| `SHUVCODE_DESKTOP_URL` | `https://app.opencode.ai` | Desktop web UI URL (when web UI enabled) |
| `ANTHROPIC_API_KEY` | - | Anthropic API key (optional) |
| `OPENAI_API_KEY` | - | OpenAI API key (optional) |
| `GOOGLE_API_KEY` | - | Google Gemini API key (optional) |

### Volume Mappings

| Container Path | Purpose |
|---------------|---------|
| `/home/opencode/.config/opencode` | Configuration files |
| `/home/opencode/.local/share/opencode` | Session data and logs |
| `/home/opencode/.local/state/opencode` | State files |
| `/home/opencode/.cache/opencode` | Cache (safe to clear) |
| `/home/opencode/.ssh` | SSH keys for git |
| `/projects` | Your project files |

## Connecting to the Server

### Option 1: OpenCode Desktop App (Recommended)

1. Download the OpenCode desktop app from [opencode.ai](https://opencode.ai)
2. Configure it to connect to your server: `http://your-unraid-ip:4096`
3. Use `/connect` to configure your LLM provider

### Option 2: Enable Built-in Web UI

Set `ENABLE_WEB_UI=true` to run the web interface on a separate port:

```yaml
environment:
  - ENABLE_WEB_UI=true
  - WEB_PORT=4097
```

Access at `http://your-unraid-ip:4097`

### Option 3: OpenCode CLI

From any machine with OpenCode installed:

```bash
opencode attach http://your-unraid-ip:4096
```

## OpenCode vs Shuvcode

This container includes both CLIs. Set `OPENCODE_CLI` to choose:

| CLI | Description |
|-----|-------------|
| `opencode` | Mainline OpenCode - stable, official releases |
| `shuvcode` | Enhanced fork with mobile PWA, UI improvements, faster community PR merges |

**Shuvcode enhancements:**
- Mobile-first PWA with iOS/Android support
- Session search (Ctrl+/)
- ANSI terminal color support
- Live token tracking
- Subagent navigation
- Custom server URLs
- Granular file permissions

## Installing Custom Packages

Install additional packages at container startup:

```yaml
environment:
  - EXTRA_APT_PACKAGES=golang ruby lua5.4 sqlite3
  - EXTRA_NPM_PACKAGES=typescript tsx pnpm yarn
  - EXTRA_PIP_PACKAGES=black ruff mypy pytest
```

## Auto-Updates

The container automatically checks for updates (default: every hour). When an update is available:

1. Checks if any sessions are currently active via `/session/status` API
2. If sessions are active, postpones the update
3. If no sessions, installs the update and restarts the service

To disable:
```yaml
environment:
  - OPENCODE_DISABLE_AUTOUPDATE=true
```

## Setting Up LLM Providers

### Option 1: Interactive Setup

1. Connect to the server (desktop app, web UI, or CLI)
2. Type `/connect` and press Enter
3. Select your provider and follow the prompts

### Option 2: Environment Variables

```yaml
environment:
  - ANTHROPIC_API_KEY=sk-ant-...
  - OPENAI_API_KEY=sk-...
  - GOOGLE_API_KEY=...
```

### Option 3: Configuration File

Create `opencode.json` in the config volume:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-sonnet-4-5"
}
```

## Included Development Tools

- **Node.js 22** - JavaScript/TypeScript runtime
- **npm** - Node package manager
- **Python 3.11** - Python interpreter with pip
- **git** - Version control (with LFS support)
- **build-essential** - C/C++ compiler and tools
- **ripgrep (rg)** - Fast text search
- **fd** - Fast file finder
- **jq** - JSON processor
- **curl/wget** - HTTP clients
- **ssh** - SSH client for git operations
- **htop** - Process viewer

## SSH Keys for Git

Mount your SSH keys for private repository access:

```yaml
volumes:
  - ~/.ssh:/home/opencode/.ssh:ro
```

Or use a dedicated directory:
```yaml
volumes:
  - /mnt/user/appdata/opencode/ssh:/home/opencode/.ssh
```

Ensure proper permissions (600 for private keys).

## Troubleshooting

### Container won't start

Check the logs:
```bash
docker logs opencode
```

### Permission issues

Ensure PUID/PGID match your Unraid user (default: 99/100 for nobody/users).

### Can't connect from desktop app

1. Verify the container is running: `docker ps`
2. Check port 4096 is accessible
3. Verify health: `curl http://your-server:4096/global/health`

### Web UI not accessible

1. Ensure `ENABLE_WEB_UI=true` is set
2. Check port 4097 is exposed and accessible
3. Verify both ports are mapped in your Docker config

### Package installation fails

Check container logs for specific errors. Ensure package names are correct for the respective package manager.

## Building Locally

```bash
git clone https://github.com/thesammykins/opencode-unraid.git
cd opencode-unraid
docker build -t opencode-unraid .
docker-compose up -d
```

## Image Versioning

| Tag | Description |
|-----|-------------|
| `latest` | Most recent build from main branch |
| `weekly-YYYYMMDD` | Weekly builds with date stamp |
| `sha-xxxxxx` | Specific commit builds |

Weekly builds automatically pull latest packages and security patches.

## License

This project is licensed under the MIT License. OpenCode and Shuvcode are also MIT licensed.

## Links

- [OpenCode GitHub](https://github.com/sst/opencode)
- [Shuvcode GitHub](https://github.com/Latitudes-Dev/shuvcode)
- [OpenCode Documentation](https://opencode.ai/docs)
- [Unraid Forums](https://forums.unraid.net/)
