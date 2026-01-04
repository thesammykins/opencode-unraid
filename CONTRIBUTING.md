# Contributing to OpenCode for Unraid

Thanks for your interest in contributing! This document outlines how to get started.

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/thesammykins/opencode-unraid.git
   cd opencode-unraid
   ```

2. Build the Docker image locally:
   ```bash
   docker build -t opencode-unraid:dev .
   ```

3. Run for testing:
   ```bash
   docker-compose up -d
   ```

4. Verify the health endpoint:
   ```bash
   curl http://localhost:4096/global/health
   ```

## Making Changes

### Before You Start

- Check existing issues and PRs to avoid duplicate work
- For significant changes, open an issue first to discuss the approach

### Code Guidelines

- Follow existing patterns in the codebase
- Test changes locally with `docker build` before submitting
- Verify PUID/PGID handling works with custom values
- Ensure the health check passes

### Commit Messages

Use clear, descriptive commit messages:
- `fix:` for bug fixes
- `feat:` for new features
- `docs:` for documentation changes
- `chore:` for maintenance tasks

### Pull Requests

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Test locally with `docker-compose up`
5. Submit a PR with a clear description

## Testing Checklist

Before submitting a PR, verify:

- [ ] `docker build` succeeds without errors
- [ ] Container starts and health check passes
- [ ] Custom PUID/PGID values work correctly
- [ ] EXTRA_*_PACKAGES environment variables work
- [ ] Web UI is accessible at the configured port

## Reporting Issues

When reporting issues, include:

- Unraid version
- Container logs (`docker logs opencode`)
- Steps to reproduce
- Expected vs actual behavior

## Questions?

Open an issue or check the [Unraid Forums](https://forums.unraid.net/) for community support.
