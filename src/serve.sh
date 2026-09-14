#!/bin/sh

[ -f .env ] && . ./.env

. "${ROOT_DIR:-.}/src/log.sh"
. "${ROOT_DIR:-.}/src/http.sh"

: "${SERVE_ROOT:=./page}"
: "${SERVE_404:=./page/404.html}"

# ------------------------------------------------------------------------------

_CR="$(printf '\r')"
serve() { (
    IFS=' ' read -r method path protocol || {
        debug 'Failed to parse http Start line'
        http_response_400
        return
    }

    protocol=${protocol%$_CR} # Trim off the '\r'

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

        case "$header" in
            If-None-Match:*) req_if_none_match="${header#*\"}"   
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

    etag=$(_file_etag "$file")

    [ "${req_if_none_match:-}" = "$etag" ] && {
        info 'http response: 304 Not Modified - %s' "$file"
        _http_response_headers "304" 'Not Modified' \
            "ETag: \"$etag\""
        return
    }

    reason=$(_http_reason "$status")
    content_type=$(_content_type "$file")
    length=$(wc -c < "$file")

    info 'http response: %s - %s' "$status" "$file"
    
    _http_response_headers "$status" '' \
        "Content-Type: $content_type" \
        "Content-Length: $length" \
        "Cache-Control: max-age=3600" \
        "ETag: \"$etag\""

    [ "$method" = "HEAD" ] || cat "$file"
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

    file="${SERVE_ROOT}${path}"

    serve_file 200 "$file"
) }

_content_type() {
    case "$1" in
        *.html|*.htm)   printf '%s' 'text/html; charset=utf-8' ;;
        *.css)          printf '%s' 'text/css; charset=utf-8' ;;
        *.js|*.mjs)     printf '%s' 'text/javascript; charset=utf-8' ;;
        *.json)         printf '%s' 'application/json' ;;
        *.txt)          printf '%s' 'text/plain; charset=utf-8' ;;
        *.xml)          printf '%s' 'application/xml' ;;
        *.svg)          printf '%s' 'image/svg+xml' ;;
        *.png)          printf '%s' 'image/png' ;;
        *.jpg|*.jpeg)   printf '%s' 'image/jpeg' ;;
        *.gif)          printf '%s' 'image/gif' ;;
        *.webp)         printf '%s' 'image/webp' ;;
        *.ico)          printf '%s' 'image/x-icon' ;;
        *.woff)         printf '%s' 'font/woff' ;;
        *.woff2)        printf '%s' 'font/woff2' ;;
        *.pdf)          printf '%s' 'application/pdf' ;;
        *)              printf '%s' 'application/octet-stream' ;;
    esac
}

_not_found() {
    if [ -n "$SERVE_404" ] && [ -f "$SERVE_404" ]; then
        if [ "${method:-}" = "HEAD" ]; then
            serve_file_head 404 "$SERVE_404"
        else
            serve_file 404 "$SERVE_404"
        fi
    else
        http_response_404
    fi
}

_file_etag() { cksum "$1" | cut -d ' ' -f 1; }

# ------------------------------------------------------------------------------

if [ "$LOG_LEVEL" = "DEBUG" ]; then
    tee /dev/stderr | serve
else
    serve
fi

