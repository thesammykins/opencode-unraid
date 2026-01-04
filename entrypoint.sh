#!/bin/bash
set -e

PUID=${PUID:-99}
PGID=${PGID:-100}
PORT=${PORT:-4096}
WEB_PORT=${WEB_PORT:-4097}
ENABLE_WEB_UI=${ENABLE_WEB_UI:-false}
OPENCODE_CLI=${OPENCODE_CLI:-shuvcode}
EXTRA_APT_PACKAGES="${EXTRA_APT_PACKAGES:-}"
EXTRA_NPM_PACKAGES="${EXTRA_NPM_PACKAGES:-}"
EXTRA_PIP_PACKAGES="${EXTRA_PIP_PACKAGES:-}"
UPDATE_CHECK_INTERVAL="${UPDATE_CHECK_INTERVAL:-3600}"
OPENCODE_PID_FILE="/tmp/opencode.pid"
WEB_PID_FILE="/tmp/opencode-web.pid"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [entrypoint] $1"
}

validate_cli() {
    case "$OPENCODE_CLI" in
        opencode|shuvcode)
            if ! command -v "$OPENCODE_CLI" &> /dev/null; then
                log "ERROR: $OPENCODE_CLI not found in PATH"
                exit 1
            fi
            log "Using CLI: $OPENCODE_CLI"
            ;;
        *)
            log "ERROR: Invalid OPENCODE_CLI value: $OPENCODE_CLI (must be 'opencode' or 'shuvcode')"
            exit 1
            ;;
    esac
}

install_extra_packages() {
    if [ -n "$EXTRA_APT_PACKAGES" ]; then
        log "Installing extra APT packages: $EXTRA_APT_PACKAGES"
        apt-get update
        apt-get install -y --no-install-recommends $EXTRA_APT_PACKAGES
        rm -rf /var/lib/apt/lists/*
        log "APT packages installed successfully"
    fi

    if [ -n "$EXTRA_NPM_PACKAGES" ]; then
        log "Installing extra NPM packages: $EXTRA_NPM_PACKAGES"
        npm install -g $EXTRA_NPM_PACKAGES
        log "NPM packages installed successfully"
    fi

    if [ -n "$EXTRA_PIP_PACKAGES" ]; then
        log "Installing extra PIP packages: $EXTRA_PIP_PACKAGES"
        pip3 install --break-system-packages $EXTRA_PIP_PACKAGES
        log "PIP packages installed successfully"
    fi
}

setup_user_permissions() {
    if [ "$(id -u opencode 2>/dev/null)" != "${PUID}" ] || [ "$(id -g opencode 2>/dev/null)" != "${PGID}" ]; then
        log "Adjusting user opencode to UID:${PUID} GID:${PGID}"
        groupmod -o -g "${PGID}" opencode 2>/dev/null || true
        usermod -o -u "${PUID}" opencode 2>/dev/null || true
    fi

    chown -R opencode:opencode \
        /home/opencode/.config \
        /home/opencode/.local \
        /home/opencode/.cache \
        2>/dev/null || true

    if [ -d "/projects" ]; then
        chown opencode:opencode /projects 2>/dev/null || true
    fi
}

start_update_checker() {
    if [ "${OPENCODE_DISABLE_AUTOUPDATE}" = "true" ]; then
        log "Auto-update disabled, skipping update checker"
        return
    fi

    if [ -x "/usr/local/bin/update-checker.sh" ]; then
        log "Starting background update checker (interval: ${UPDATE_CHECK_INTERVAL}s)"
        /usr/local/bin/update-checker.sh &
    fi
}

start_web_ui() {
    if [ "${ENABLE_WEB_UI}" != "true" ]; then
        return
    fi

    if [ "${PORT}" = "${WEB_PORT}" ]; then
        log "ERROR: PORT and WEB_PORT cannot be the same (both set to ${PORT})"
        exit 1
    fi

    log "Starting Web UI on port ${WEB_PORT}"
    "$OPENCODE_CLI" web --hostname 0.0.0.0 --port "${WEB_PORT}" &
    echo $! > "$WEB_PID_FILE"
    log "Web UI started (PID: $(cat $WEB_PID_FILE))"
}

run_serve() {
    log "Starting ${OPENCODE_CLI} headless server on port ${PORT}"
    echo $$ > "$OPENCODE_PID_FILE"
    exec "$OPENCODE_CLI" serve --hostname 0.0.0.0 --port "${PORT}"
}

main() {
    validate_cli

    if [ "$(id -u)" = '0' ]; then
        install_extra_packages
        setup_user_permissions
        start_update_checker

        log "Dropping privileges to user opencode (${PUID}:${PGID})"
        exec gosu opencode "$0" "$@"
    fi

    start_web_ui
    run_serve
}

main "$@"
