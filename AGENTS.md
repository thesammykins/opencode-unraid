# Shuvcode for Unraid - Agent Guidelines

## Project Overview

Docker container project wrapping [Shuvcode](https://github.com/Latitudes-Dev/shuvcode) (enhanced OpenCode fork) AI coding agent for Unraid servers with web UI support.

**Purpose**: Enable Unraid users to run Shuvcode from any browser on their network with persistent configuration in appdata.

## Architecture

```
opencode_unraid/
├── Dockerfile          # Container build (node:22-bookworm + dev tools)
├── entrypoint.sh       # PUID/PGID handling, package install, privilege drop
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
- **Update checker**: Background script checks for updates, restarts when no active sessions

### XDG Directory Mapping
Container uses XDG spec, mapped to Unraid appdata:
| Container Path | Unraid Path | Purpose |
|---------------|-------------|---------|
| `~/.config/opencode` | `/mnt/user/appdata/shuvcode/config` | Config files |
| `~/.local/share/opencode` | `/mnt/user/appdata/shuvcode/data` | Session data |
| `~/.local/state/opencode` | `/mnt/user/appdata/shuvcode/state` | State files |
| `~/.cache/opencode` | `/mnt/user/appdata/shuvcode/cache` | Cache (safe to clear) |
| `~/.ssh` | `/mnt/user/appdata/shuvcode/ssh` | SSH keys for git |

### Web Mode
Shuvcode runs in web mode by default:
```bash
shuvcode web --hostname 0.0.0.0 --port ${PORT}
```
- Port 4096 default
- Binds to 0.0.0.0 (required for container networking)
- HTTPS handled externally via reverse proxy

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

## Build & Test Commands

```bash
# Build image
docker build -t opencode-unraid .

# Run for testing
docker-compose up -d

# Check health
curl http://localhost:4096/global/health

# Check active sessions
curl http://localhost:4096/session/status

# View logs
docker logs shuvcode

# Shell into container
docker exec -it shuvcode bash
```

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `PUID` | 99 | User ID |
| `PGID` | 100 | Group ID |
| `PORT` | 4096 | Web server port |
| `EXTRA_APT_PACKAGES` | - | Space-separated apt packages |
| `EXTRA_NPM_PACKAGES` | - | Space-separated npm packages |
| `EXTRA_PIP_PACKAGES` | - | Space-separated pip packages |
| `UPDATE_CHECK_INTERVAL` | 3600 | Seconds between update checks |
| `OPENCODE_DISABLE_AUTOUPDATE` | - | Set `true` to disable |

## Unraid Template (XML)

The `unraid/opencode.xml` follows Unraid CA format:
- `<Repository>`: GHCR image path
- `<Config Type="Path">`: Volume mappings
- `<Config Type="Variable">`: Environment variables
- `<Config Type="Port">`: Port mappings
- `Mask="true"`: Hides sensitive values (API keys)

## Known Issues / TODOs

1. **Version pinning**: `shuvcode@latest` is non-deterministic
   - Consider pinning specific version for reproducible builds

2. **Upstream limitation**: Web UI cannot create new projects
   - Users must pre-create projects on host or use `docker exec` to create inside container
   - This is an OpenCode/Shuvcode limitation, not container-specific

## Testing Checklist

Before releasing:
- [ ] Docker build succeeds
- [ ] Container starts without errors
- [ ] Health check passes (`/global/health`)
- [ ] Update checker starts in background
- [ ] Web UI accessible from browser
- [ ] PUID/PGID correctly applied (check file ownership)
- [ ] Config persists across container restart
- [ ] Shuvcode can access mounted projects
- [ ] API key configuration works via `/connect`
- [ ] EXTRA_*_PACKAGES install correctly
- [ ] Auto-update triggers when no sessions active

## Contributing

1. Test changes locally with `docker-compose up`
2. Verify health endpoint returns `{"healthy":true}`
3. Check file permissions with custom PUID/PGID
4. Update SPEC.md if architecture changes
