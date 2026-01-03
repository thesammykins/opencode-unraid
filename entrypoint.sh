#!/bin/bash
set -e

PUID=${PUID:-99}
PGID=${PGID:-100}
PORT=${PORT:-4096}

if [ "$(id -u)" = '0' ]; then
    if [ "$(id -u opencode)" != "${PUID}" ] || [ "$(id -g opencode)" != "${PGID}" ]; then
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

    exec gosu opencode "$@" --hostname 0.0.0.0 --port "${PORT}"
fi

exec "$@" --hostname 0.0.0.0 --port "${PORT}"
