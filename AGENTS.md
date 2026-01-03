# OpenCode for Unraid - Agent Guidelines

## Project Overview

Docker container project wrapping [OpenCode](https://github.com/anomalyco/opencode) AI coding agent for Unraid servers with web UI support.

**Purpose**: Enable Unraid users to run OpenCode from any browser on their network with persistent configuration in appdata.

## Architecture

```
opencode_unraid/
├── Dockerfile          # Container build (node:22-bookworm + dev tools)
├── entrypoint.sh       # PUID/PGID handling, privilege drop via gosu
├── docker-compose.yml  # Local development/testing
├── unraid/
│   └── opencode.xml    # Unraid Community Applications template
├── SPEC.md             # Technical specification
└── README.md           # User documentation
```

## Key Patterns

### Container Architecture
- **Base**: `node:22-bookworm` (NOT alpine - dev tools need glibc)
- **Init**: `tini` for proper signal handling
- **Privilege drop**: `gosu` (NOT su-exec) for PUID/PGID support
- **User**: `opencode` with configurable UID/GID at runtime

### XDG Directory Mapping
Container uses XDG spec, mapped to Unraid appdata:
| Container Path | Unraid Path | Purpose |
|---------------|-------------|---------|
| `~/.config/opencode` | `/mnt/user/appdata/opencode/config` | Config files |
| `~/.local/share/opencode` | `/mnt/user/appdata/opencode/data` | Session data |
| `~/.local/state/opencode` | `/mnt/user/appdata/opencode/state` | State files |
| `~/.cache/opencode` | `/mnt/user/appdata/opencode/cache` | Cache (safe to clear) |

### Web Mode
OpenCode runs in web mode by default:
```bash
opencode web --hostname 0.0.0.0 --port ${PORT}
```
- Port 4096 default
- Binds to 0.0.0.0 (required for container networking)
- HTTPS handled externally via reverse proxy

## Anti-Patterns (NEVER DO)

| Violation | Why |
|-----------|-----|
| Create group with GID 100 | Already exists as 'users' in Debian base |
| Use `--privileged` mode | Security risk, not needed |
| Embed API keys in image | Store in persistent volume only |
| Bind to localhost/127.0.0.1 | Container won't be accessible externally |
| Use alpine base | Dev tools need glibc, native modules fail |
| Remove gosu/tini | Breaks PUID/PGID and signal handling |

## Build & Test Commands

```bash
# Build image
docker build -t opencode-unraid .

# Run for testing
docker-compose up -d

# Check health
curl http://localhost:4096/global/health

# View logs
docker logs opencode

# Shell into container
docker exec -it opencode bash
```

## Unraid Template (XML)

The `unraid/opencode.xml` follows Unraid CA format:
- `<Repository>`: GHCR image path
- `<Config Type="Path">`: Volume mappings
- `<Config Type="Variable">`: Environment variables
- `<Config Type="Port">`: Port mappings
- `Mask="true"`: Hides sensitive values (API keys)

## Known Issues / TODOs

1. **OWNER placeholders**: Replace with actual GitHub org before publishing
   - `Dockerfile` labels
   - `unraid/opencode.xml` Repository/Registry/Support
   - `README.md` image references
   - `docker-compose.yml` image reference

2. **Version pinning**: `opencode-ai@latest` is non-deterministic
   - Consider pinning specific version for reproducible builds

3. **XML Date tag**: Missing `<Date>` tag in XML template
   - Add before CA submission: `<Date>2026-01-04</Date>`

## Testing Checklist

Before releasing:
- [ ] Docker build succeeds
- [ ] Container starts without errors
- [ ] Health check passes (`/global/health`)
- [ ] Web UI accessible from browser
- [ ] PUID/PGID correctly applied (check file ownership)
- [ ] Config persists across container restart
- [ ] OpenCode can access mounted projects
- [ ] API key configuration works via `/connect`

## Contributing

1. Test changes locally with `docker-compose up`
2. Verify health endpoint returns `{"healthy":true}`
3. Check file permissions with custom PUID/PGID
4. Update SPEC.md if architecture changes
