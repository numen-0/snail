#!/bin/sh

[ -f .env ] && . ./.env

. "${APP_DIR:-.}/src/lib/log.sh"
. "${APP_DIR:-.}/src/lib/http.sh"
. "${APP_DIR:-.}/src/lib/utils.sh"

: "${STATIC_ROOT:="${APP_DIR:-.}/data/static"}"
: "${STATIC_404:="${STATIC_ROOT}/404.html"}"

# ------------------------------------------------------------------------------

_CR="$(printf '\r')"
serve() { (
    IFS=' ' read -r method path protocol || {
        debug 'Failed to parse http Start line'
        http_response_400
        return
    }

    protocol="${protocol%"$_CR"}" # Trim off the '\r'

    info 'request: %s %s %s' "$method" "$path" "$protocol"

    [ "$protocol" = 'HTTP/1.1' ] || {
        debug 'HTTP version not supported: %s' "$protocol"
        http_response_505
        return
    }

    req_if_none_match=""

    while IFS= read -r header; do
        [ "$header" = "$_CR" ] && break

        [ -n "$header" ] && _validate_headers "$header" || {
            http_response_400
            return
        }

        case "$(str_lower "$header_name")" in
            if-none-match:*) req_if_none_match="${header#*\"}"
                             req_if_none_match="${req_if_none_match%%\"*}" ;;
        esac
    done

    case "$method" in
        GET|HEAD) _serve_file "$path" ;;
        *) debug 'Method not allowed: %s' "$method"
           http_response_405 ;;
    esac
) }

serve_file() { (
    status=$1; file=$2; shift 2;

   _validate_status "$status" && _validate_headers "$@" || {
        http_response_500
        return
    }

    [ -f "$file" ] || { _not_found; return; }

    etag=$(file_etag "$file")

    [ "${req_if_none_match:-}" = "$etag" ] && {
        info 'http response: 304 Not Modified - %s' "$file"
        _http_response_headers "304" 'Not Modified' \
            "ETag: \"$etag\""
        return
    }

    reason=$(_http_reason "$status")
    content_type=$(file_content_type "$file")
    length=$(wc -c < "$file")

    info 'http response: %s %s - %s' "$status" "$reason" "$file"

    _http_response_headers "$status" "$reason" \
        "Content-Type: $content_type" \
        "Content-Length: $length" \
        "Cache-Control: max-age=3600" \
        "ETag: \"$etag\"" \
        "$@"

    [ "${method:-}" = "HEAD" ] || cat "$file"
) }

# ------------------------------------------------------------------------------

_serve_file() { (
    path=$1; shift;
    path=${path%%\?*}

    case "$path" in
        *..*)   http_response_400; return ;;
        */)     path="${path}index.html" ;;
        /*)     ;;
        *)      http_response_400; return ;;
    esac

    file="${STATIC_ROOT}${path}"

    serve_file 200 "$file"
) }

_not_found() {
    if [ -n "$STATIC_404" ] && [ -f "$STATIC_404" ]; then
        if [ "${method:-}" = "HEAD" ]; then
            serve_file_head 404 "$STATIC_404"
        else
            serve_file 404 "$STATIC_404"
        fi
    else
        http_response_404
    fi
}

# ------------------------------------------------------------------------------

if [ "$LOG_LEVEL" = "DEBUG" ]; then
    tee /dev/stderr | serve
else
    serve
fi

