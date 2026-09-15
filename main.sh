#!/bin/sh
set -eu

[ -f .env ] && . ./.env

. "${APP_DIR:-.}/src/lib/http.sh"
. "${APP_DIR:-.}/src/lib/log.sh"

debug 'Server config:\n%s' "$(cat <<EOF
APP_DIR="$APP_DIR"
APP_HANDLER="$APP_HANDLER"

HTTP_HOST="$HTTP_HOST"
HTTP_PORT="$HTTP_PORT"

LOG_NAME="$LOG_NAME"
LOG_LEVEL="$LOG_LEVEL"
LOG_FMT="$LOG_FMT"
LOG_FILE="$LOG_FILE"
LOG_COLOR="$LOG_COLOR"


STATIC_ROOT="$STATIC_ROOT"
STATIC_404="$STATIC_404"

SHARE_ROOT="$SHARE_ROOT"
EOF
)"

http_server "${HTTP_PORT:-8080}" "$APP_HANDLER"

