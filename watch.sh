#!/bin/sh
set -eu

. "${ROOT_DIR:-.}/src/lib/log.sh"

[ -f .env ] && . ./.env

: "${WATCH_CLEAR:=true}"
LOG_NAME="watcher"

WATCH="${ROOT_DIR:-.}/watch.sh"
MAIN="${ROOT_DIR:-.}/main.sh"

start_main() {
    setsid sh "$MAIN" &
    MAIN_PID=$!
}

stop_main() { kill -- "-$MAIN_PID" 2>/dev/null || true; }

info "starting main script..."
start_main
trap 'stop_main' EXIT INT TERM

touch "$WATCH"

while sleep 1; do
    if find ./data/static src "$MAIN" \
        -newer "$WATCH" \
        -print -quit \
        | grep -q .
    then
        touch "$WATCH"
        info "change detected, restarting..."

        stop_main
            
        [ "$WATCH_CLEAR" = "true" ] && clear

        start_main
    fi
done
