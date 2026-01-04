# Shuvcode for Unraid

Docker container running [Shuvcode](https://github.com/Latitudes-Dev/shuvcode) (enhanced OpenCode fork) with web interface support, designed for Unraid servers.

Shuvcode is an enhanced fork of OpenCode - an open-source AI coding agent that helps you write, debug, and refactor code using LLMs from a variety of providers. This fork includes additional features like mobile PWA support, enhanced UI, and community-contributed improvements.

## Features

- **Web-based UI** - Access Shuvcode from any browser on your network
- **Mobile PWA support** - Full-featured mobile Progressive Web App
- **Development ready** - Includes Node.js, Python, npm, git, and build tools
- **Persistent configuration** - Config and sessions stored in Unraid appdata
- **Multi-provider support** - Works with Anthropic, OpenAI, Google, Azure, Groq, and local models
- **Auto-updates** - Automatically updates Shuvcode when no sessions are active
- **Custom packages** - Install additional apt, npm, or pip packages at runtime
- **SSH support** - Mount SSH keys for git operations
- **Enhanced features** - Custom server URLs, IDE integration, improved spinner styles, and more

## Quick Start

### Unraid Community Applications

1. Search for "Shuvcode" in Community Applications
2. Click Install
3. Configure the paths and port
4. Start the container
5. Open the WebUI and run `/connect` to configure your LLM provider

### Manual Template Installation (Before CA Approval)

If this template isn't yet in Community Applications, add it manually:

1. Go to **Settings** → **Docker** → **Template Repositories**
2. Add this URL:
   ```
   https://raw.githubusercontent.com/thesammykins/opencode-unraid/main/unraid/opencode.xml
   ```
3. Save and go to **Docker** → **Add Container**
4. Select **Template: shuvcode** from the dropdown
5. Configure paths and click Apply

### Docker Compose

```yaml
version: "3.8"

services:
  shuvcode:
    image: ghcr.io/thesammykins/opencode-unraid:latest
    container_name: shuvcode
    ports:
      - "4096:4096"
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
    restart: unless-stopped
```

### Docker CLI

```bash
docker run -d \
  --name shuvcode \
  -p 4096:4096 \
  -v /mnt/user/appdata/shuvcode/config:/home/opencode/.config/opencode \
  -v /mnt/user/appdata/shuvcode/data:/home/opencode/.local/share/opencode \
  -v /mnt/user/appdata/shuvcode/state:/home/opencode/.local/state/opencode \
  -v /mnt/user/appdata/shuvcode/cache:/home/opencode/.cache/opencode \
  -v /mnt/user/appdata/shuvcode/ssh:/home/opencode/.ssh \
  -v /mnt/user/projects:/projects \
  -e PUID=99 \
  -e PGID=100 \
  -e TZ=Etc/UTC \
  ghcr.io/thesammykins/opencode-unraid:latest
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | 99 | User ID for file permissions |
| `PGID` | 100 | Group ID for file permissions |
| `TZ` | `Etc/UTC` | Container timezone |
| `PORT` | 4096 | Web server port |
| `EXTRA_APT_PACKAGES` | - | Space-separated apt packages to install |
| `EXTRA_NPM_PACKAGES` | - | Space-separated npm packages to install globally |
| `EXTRA_PIP_PACKAGES` | - | Space-separated pip packages to install |
| `UPDATE_CHECK_INTERVAL` | 3600 | Seconds between update checks |
| `OPENCODE_DISABLE_AUTOUPDATE` | - | Set to `true` to disable auto-updates |
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

## Installing Custom Packages

You can install additional packages at container startup using environment variables:

```yaml
environment:
  # Install system packages
  - EXTRA_APT_PACKAGES=golang ruby lua5.4 sqlite3
  
  # Install Node.js packages globally
  - EXTRA_NPM_PACKAGES=typescript tsx pnpm yarn
  
  # Install Python packages
  - EXTRA_PIP_PACKAGES=black ruff mypy pytest
```

Packages are installed on every container start to ensure freshness. For frequently used packages, consider building a custom image.

## Auto-Updates

The container automatically checks for Shuvcode updates (default: every hour). When an update is available:

1. Checks if any sessions are currently active via `/session/status` API
2. If sessions are active, postpones the update
3. If no sessions, installs the update and restarts the service

To disable auto-updates:
```yaml
environment:
  - OPENCODE_DISABLE_AUTOUPDATE=true
```

## Setting Up LLM Providers

After starting the container, open the web UI and configure your LLM provider:

### Option 1: Interactive Setup (Recommended)

1. Open the WebUI at `http://your-server:4096`
2. Type `/connect` and press Enter
3. Select your provider and follow the prompts
4. Enter your API key when prompted

### Option 2: Environment Variables

Set API keys via environment variables:
- `ANTHROPIC_API_KEY` for Claude models
- `OPENAI_API_KEY` for GPT models
- `GOOGLE_API_KEY` for Gemini models

### Option 3: Configuration File

Create `opencode.json` in the config volume:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-sonnet-4-5"
}
```

## Included Development Tools

The container includes these tools for AI-assisted development:

- **Node.js 22** - JavaScript/TypeScript runtime
- **npm** - Node package manager
- **Python 3.11** - Python interpreter
- **pip** - Python package manager
- **git** - Version control (with LFS support)
- **build-essential** - C/C++ compiler and tools
- **ripgrep (rg)** - Fast text search
- **fd** - Fast file finder
- **jq** - JSON processor
- **curl/wget** - HTTP clients
- **ssh** - SSH client for git operations
- **htop** - Process viewer

## SSH Keys for Git

Mount your SSH keys to enable git operations with private repositories:

```yaml
volumes:
  - ~/.ssh:/home/opencode/.ssh:ro
```

Or copy specific keys:
```yaml
volumes:
  - /mnt/user/appdata/shuvcode/ssh:/home/opencode/.ssh
```

Ensure proper permissions (600 for private keys).

## Usage Tips

### Working with Projects

Mount your project directories to `/projects`:

```yaml
volumes:
  - /mnt/user/development:/projects
```

Then in Shuvcode, navigate to your project:
```
cd /projects/my-app
```

### Custom Agents

Create custom agents by adding markdown files to your config:
```
/mnt/user/appdata/shuvcode/config/agent/my-agent.md
```

### Custom Commands

Create custom commands:
```
/mnt/user/appdata/shuvcode/config/command/my-command.md
```

### MCP Servers

Configure MCP servers in your `opencode.json`:
```json
{
  "mcp": {
    "filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/projects"]
    }
  }
}
```

## Troubleshooting

### Container won't start

Check the logs:
```bash
docker logs shuvcode
```

### Permission issues

Ensure PUID/PGID match your Unraid user (default: 99/100 for nobody/users).

### Can't connect to LLM

1. Verify your API key is correct
2. Check network connectivity
3. Try `/connect` again to reconfigure

### Web UI not accessible

1. Check the container is running: `docker ps`
2. Verify port 4096 is not in use
3. Check Unraid firewall settings

### Package installation fails

Check container logs for specific errors. Ensure package names are correct for the respective package manager.

### Can't create new projects from Web UI

This is an upstream limitation - the web interface doesn't support creating new projects. Workarounds:

1. **Pre-create projects** on your host and mount them to `/projects`
2. **Use the terminal** inside the container: `docker exec -it shuvcode bash` then use `git clone` or `mkdir`
3. **Create via the mounted volume** directly on your Unraid server at the path mapped to `/projects`

## Building Locally

```bash
git clone https://github.com/thesammykins/opencode-unraid.git
cd opencode-unraid
docker build -t opencode-unraid .
docker-compose up -d
```

## Image Versioning

This image uses weekly automated builds to stay current:

| Tag | Description |
|-----|-------------|
| `latest` | Most recent build from main branch |
| `weekly-YYYYMMDD` | Weekly builds with date stamp |
| `sha-xxxxxx` | Specific commit builds |

Weekly builds automatically pull:
- Latest `shuvcode` npm package
- Updated `node:22-bookworm` base image
- Security patches for system packages

Dependabot monitors and creates PRs for base image and GitHub Actions updates.

## License

This project is licensed under the MIT License. Shuvcode and OpenCode are also MIT licensed.

## Links

- [Shuvcode GitHub](https://github.com/Latitudes-Dev/shuvcode)
- [OpenCode Documentation](https://opencode.ai/docs)
- [Unraid Forums](https://forums.unraid.net/)
