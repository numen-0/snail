#!/bin/sh
set -eu

[ -f .env ] && . ./.env

. "${ROOT_DIR:-.}/src/http.sh"
. "${ROOT_DIR:-.}/src/log.sh"

debug 'Server config:\n%s' "$(cat <<EOF
ROOT_DIR="$ROOT_DIR"

HTTP_HOST="$HTTP_HOST"
HTTP_PORT="$HTTP_PORT"

SERVE_ROOT="$SERVE_ROOT"
SERVE_404="$SERVE_404"

LOG_NAME="$LOG_NAME"
LOG_LEVEL="$LOG_LEVEL"
LOG_FMT="$LOG_FMT"
LOG_FILE="$LOG_FILE"
LOG_COLOR="$LOG_COLOR"
EOF
)"

http_server "${HTTP_PORT:-8080}" "${ROOT_DIR:-.}/src/serve.sh"

