# OpenCode for Unraid - Agent Guidelines

## Project Overview

Docker container project wrapping [OpenCode](https://github.com/sst/opencode) (or [Shuvcode](https://github.com/Latitudes-Dev/shuvcode) fork) AI coding agent for Unraid servers with headless API server and optional web UI.

**Purpose**: Enable Unraid users to run OpenCode as a headless server that other clients can connect to, with persistent configuration in appdata.

## Architecture

```
opencode_unraid/
├── Dockerfile          # Container build (node:22-bookworm + dev tools)
├── entrypoint.sh       # PUID/PGID handling, CLI selection, dual-mode support
├── scripts/
│   └── update-checker.sh  # Background auto-update with session detection
├── docker-compose.yml  # Local development/testing
├── unraid/
│   └── opencode.xml    # Unraid Community Applications template
├── .github/
│   ├── workflows/
│   │   ├── docker-build.yml    # Multi-arch builds, weekly schedule, GHCR
│   │   └── check-updates.yml   # Dependency version monitoring
│   └── dependabot.yml          # Automated PRs for base image updates
├── SPEC.md             # Technical specification
└── README.md           # User documentation
```

## Key Patterns

### Container Architecture
- **Base**: `node:22-bookworm` (NOT alpine - dev tools need glibc)
- **Init**: `tini` for proper signal handling
- **Privilege drop**: `gosu` (NOT su-exec) for PUID/PGID support
- **User**: `opencode` with configurable UID/GID at runtime
- **CLIs**: Both `opencode-ai` and `shuvcode` installed, selectable via env var
- **Update checker**: Background script checks for updates, restarts when no active sessions

### Dual Mode Operation
Container runs in **headless serve mode** by default:
```bash
${OPENCODE_CLI} serve --hostname 0.0.0.0 --port ${PORT}
```

Optionally enables **web UI** on separate port when `ENABLE_WEB_UI=true`:
```bash
${OPENCODE_CLI} web --hostname 0.0.0.0 --port ${WEB_PORT}
```

### XDG Directory Mapping
Container uses XDG spec, mapped to Unraid appdata:
| Container Path | Unraid Path | Purpose |
|---------------|-------------|---------|
| `~/.config/opencode` | `/mnt/user/appdata/opencode/config` | Config files |
| `~/.local/share/opencode` | `/mnt/user/appdata/opencode/data` | Session data |
| `~/.local/state/opencode` | `/mnt/user/appdata/opencode/state` | State files |
| `~/.cache/opencode` | `/mnt/user/appdata/opencode/cache` | Cache (safe to clear) |
| `~/.ssh` | `/mnt/user/appdata/opencode/ssh` | SSH keys for git |

### API Endpoints
| Endpoint | Purpose |
|----------|---------|
| `GET /global/health` | Health check `{"healthy":true}` |
| `GET /session/status` | Check active sessions (used by update-checker) |
| `GET /session` | List all sessions |
| `GET /doc` | OpenAPI 3.1 specification |

## Anti-Patterns (NEVER DO)

| Violation | Why |
|-----------|-----|
| Create group with GID 100 | Already exists as 'users' in Debian base |
| Use `--privileged` mode | Security risk, not needed |
| Embed API keys in image | Store in persistent volume only |
| Bind to localhost/127.0.0.1 | Container won't be accessible externally |
| Use alpine base | Dev tools need glibc, native modules fail |
| Remove gosu/tini | Breaks PUID/PGID and signal handling |
| Force update during active sessions | Use `/session/status` to check first |
| Use same port for API and Web UI | Must be different ports |

## Build & Test Commands

```bash
# Build image
docker build -t opencode-unraid .

# Run for testing (headless only)
docker run -d --name opencode -p 4096:4096 opencode-unraid

# Run with web UI enabled
docker run -d --name opencode -p 4096:4096 -p 4097:4097 \
  -e ENABLE_WEB_UI=true opencode-unraid

# Check health
curl http://localhost:4096/global/health

# Check active sessions
curl http://localhost:4096/session/status

# View logs
docker logs opencode

# Shell into container
docker exec -it opencode bash

# Test with mainline opencode
docker run -d --name opencode -p 4096:4096 \
  -e OPENCODE_CLI=opencode opencode-unraid
```

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `PUID` | 99 | User ID |
| `PGID` | 100 | Group ID |
| `PORT` | 4096 | Headless API server port |
| `WEB_PORT` | 4097 | Web UI port (when enabled) |
| `ENABLE_WEB_UI` | false | Enable web UI on WEB_PORT |
| `OPENCODE_CLI` | shuvcode | CLI to use: `opencode` or `shuvcode` |
| `EXTRA_APT_PACKAGES` | - | Space-separated apt packages |
| `EXTRA_NPM_PACKAGES` | - | Space-separated npm packages |
| `EXTRA_PIP_PACKAGES` | - | Space-separated pip packages |
| `UPDATE_CHECK_INTERVAL` | 3600 | Seconds between update checks |
| `OPENCODE_DISABLE_AUTOUPDATE` | - | Set `true` to disable |
| `SHUVCODE_DESKTOP_URL` | `https://app.opencode.ai` | Desktop UI URL (web UI only) |

## Desktop UI

The npm packages proxy to a hosted desktop UI instead of bundling static assets. When web UI is enabled, requests proxy to `SHUVCODE_DESKTOP_URL` (defaults to `app.opencode.ai`).

## Unraid Template (XML)

The `unraid/opencode.xml` follows Unraid CA format:
- `<Repository>`: GHCR image path
- `<Config Type="Path">`: Volume mappings
- `<Config Type="Variable">`: Environment variables
- `<Config Type="Port">`: Port mappings (4096 for API, 4097 for Web UI)
- `Mask="true"`: Hides sensitive values (API keys)

## Known Issues / TODOs

1. **Version pinning**: `shuvcode@latest` and `opencode-ai@latest` are non-deterministic
   - Consider pinning specific version for reproducible builds

2. **Upstream limitation**: Web UI cannot create new projects
   - Users must pre-create projects on host or use `docker exec` to create inside container
   - This is an OpenCode/Shuvcode limitation, not container-specific

## Testing Checklist

Before releasing:
- [ ] Docker build succeeds
- [ ] Container starts in serve mode without errors
- [ ] Health check passes (`/global/health`)
- [ ] Update checker starts in background
- [ ] CLI switching works (opencode vs shuvcode)
- [ ] Web UI works when ENABLE_WEB_UI=true
- [ ] Both ports respond when dual mode enabled
- [ ] PUID/PGID correctly applied (check file ownership)
- [ ] Config persists across container restart
- [ ] EXTRA_*_PACKAGES install correctly
- [ ] Auto-update triggers when no sessions active

## Contributing

1. Test changes locally with `docker-compose up`
2. Verify health endpoint returns `{"healthy":true}`
3. Test both CLI options (opencode and shuvcode)
4. Test with ENABLE_WEB_UI=true and ENABLE_WEB_UI=false
5. Check file permissions with custom PUID/PGID
6. Update SPEC.md if architecture changes
