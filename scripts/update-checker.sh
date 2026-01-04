#!/bin/bash
# Shuvcode Update Checker
# Periodically checks for shuvcode updates and restarts service when safe
#
# Environment variables:
#   UPDATE_CHECK_INTERVAL - Check interval in seconds (default: 3600 = 1 hour)
#   OPENCODE_DISABLE_AUTOUPDATE - Set to "true" to disable auto-updates
#   PORT - OpenCode port (default: 4096)

set -e

UPDATE_CHECK_INTERVAL="${UPDATE_CHECK_INTERVAL:-3600}"
PORT="${PORT:-4096}"
OPENCODE_PID_FILE="/tmp/opencode.pid"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [update-checker] $1"
}

get_current_version() {
    npm list -g shuvcode --depth=0 2>/dev/null | grep -oP 'shuvcode@\K[\d.]+' || echo ""
}

get_latest_version() {
    npm view shuvcode version 2>/dev/null || echo ""
}

check_active_sessions() {
    # Query OpenCode API for active sessions
    # Returns 0 (true) if sessions are active, 1 (false) if no sessions
    local response
    response=$(curl -s --max-time 5 "http://localhost:${PORT}/session/status" 2>/dev/null || echo "{}")
    
    # Check if response contains any session data (non-empty object)
    if [ "$response" = "{}" ] || [ -z "$response" ]; then
        return 1  # No active sessions
    fi
    
    # Parse JSON to check for sessions with activity
    # If any session has recent messages, consider it active
    local session_count
    session_count=$(echo "$response" | jq 'keys | length' 2>/dev/null || echo "0")
    
    if [ "$session_count" -gt 0 ]; then
        log "Found $session_count active session(s)"
        return 0  # Active sessions exist
    fi
    
    return 1  # No active sessions
}

perform_update() {
    local current_version="$1"
    local latest_version="$2"
    
    log "Installing update: $current_version -> $latest_version"
    
    if npm install -g shuvcode@latest 2>&1; then
        log "Update installed successfully"
        return 0
    else
        log "ERROR: Update installation failed"
        return 1
    fi
}

restart_opencode() {
    log "Initiating graceful restart..."
    
    # Read the PID of the main opencode process
    if [ -f "$OPENCODE_PID_FILE" ]; then
        local pid
        pid=$(cat "$OPENCODE_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            # Send SIGTERM for graceful shutdown (tini will handle restart)
            log "Sending SIGTERM to OpenCode process (PID: $pid)"
            kill -TERM "$pid"
            return 0
        fi
    fi
    
    # Fallback: signal the parent process
    log "PID file not found, sending SIGTERM to parent"
    kill -TERM 1
}

check_and_update() {
    local current_version
    local latest_version
    
    current_version=$(get_current_version)
    if [ -z "$current_version" ]; then
        log "WARNING: Could not determine current version"
        return 1
    fi
    
    latest_version=$(get_latest_version)
    if [ -z "$latest_version" ]; then
        log "WARNING: Could not fetch latest version (network issue?)"
        return 1
    fi
    
    if [ "$current_version" = "$latest_version" ]; then
        log "Up to date: v$current_version"
        return 0
    fi
    
    log "Update available: v$current_version -> v$latest_version"
    
    # Check for active sessions
    if check_active_sessions; then
        log "Active sessions detected, postponing update"
        return 0
    fi
    
    log "No active sessions, proceeding with update"
    
    if perform_update "$current_version" "$latest_version"; then
        restart_opencode
    fi
}

main() {
    log "Starting update checker (interval: ${UPDATE_CHECK_INTERVAL}s)"
    
    # Wait for OpenCode to start
    sleep 30
    
    while true; do
        if [ "${OPENCODE_DISABLE_AUTOUPDATE}" = "true" ]; then
            log "Auto-update disabled, exiting"
            exit 0
        fi
        
        check_and_update || true
        
        sleep "$UPDATE_CHECK_INTERVAL"
    done
}

# Run main function
main "$@"
