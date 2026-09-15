#!/bin/sh

[ -f .env ] && . ./.env

. "${APP_DIR:-.}/src/log.sh"
. "${APP_DIR:-.}/src/http.sh"

: "${SHARE_ROOT:=./files}"

case "$SHARE_ROOT" in
    */) error "\$SHARE_ROOT can't end with slash ('/'): %s" "$SHARE_ROOT"
        http_response_500 'Server config error' ;;
esac

[ -d "$SHARE_ROOT" ] || {
    error "\$SHARE_ROOT must be a existing directory: %s" "$SHARE_ROOT"
        http_response_500 'Server config error'
}

# TODO: accept some ?args...
#   - DELETE
#       ?force=dsasd
#   - DELETE|GET
#       ?recursive=bool
#   - GET
#       ?short=dirs
#       ?filter=files

# ------------------------------------------------------------------------------

_CR="$(printf '\r')"
serve() { (
    IFS=' ' read -r method path protocol || {
        info 'Failed to parse http Start line'
        http_response_400 'Failed to parse http Start line'
        return
    }

    protocol="${protocol%$_CR}"

    info 'request: %s %s %s' "$method" "$path" "$protocol"

    [ "$LOG_LEVEL" = "DEBUG" ] \
        && printf '%s %s %s\n' "$method" "$path" "$protocol" >&2

    [ "$protocol" = 'HTTP/1.1' ] || {
        info 'HTTP version not supported: %s' "$protocol"
        http_response_505
        return
    }

    req_content_length=""

    while IFS= read -r header; do
        [ "$header" = "$_CR" ] && break

        [ -n "$header" ] && _validate_headers "$header" || {
            http_response_400 "Invalid header: $header"
            return
        }

        header="${header%$_CR}"

        case "$(str_lower "$header")" in
            content-length:*) req_content_length="${header#*:}"
                              req_content_length="${req_content_length#* }"
                              req_content_length="${req_content_length%% *}" ;;
        esac

        [ "$LOG_LEVEL" = "DEBUG" ] \
            && printf '%s\n' "$header" >&2
    done

    case "$method" in
        HEAD|GET)   _get "$path" ;;
        POST)       _post "$path" ;;
        PUT)        _put "$path" ;;
        DELETE)     _delete "$path" ;;
        *)          debug 'Method not allowed: %s' "$method"
                    http_response_405 ;;
    esac
) }

serve_file() { (
    status=$1; file=$2; shift 2;

    _validate_status "$status" && _validate_headers "$@" || {
        http_response_500
        return
    }

    [ -f "$file" ] || { http_response_404; return; }

    reason=$(_http_reason "$status")
    content_type=$(file_content_type "$file")
    length=$(wc -c < "$file")

    info 'http response: %s %s - %s' "$status" "$reason" "$file"

    _http_response_headers "$status" "$reason" \
        "Content-Type: $content_type" \
        "Content-Length: $length" \
        "$@"

    [ "${method:-}" = "HEAD" ] || cat "$file"
) }

list_directory() { (
    status=$1; dir=$2; shift 2;

    [ -d "$dir" ] || {
        error '%s is not a directory' "$dir"
        http_response_500 'Not a directory'
        return
    }

    case "$dir" in
        */) ;;
        *)  dir="$dir/" ;;
    esac

    body=$(
        for entry in "$dir"*; do
            [ -e "$entry" ] || continue

            name=${entry#"$SHARE_ROOT"}

            [ -d "$entry" ] \
                && printf '%s/\n' "$name" \
                || printf '%s\n' "$name"
        done
    ) || {
        http_response_500 'Failed to list directory'
        return
    }

    reason=$(_http_reason "$status")
    length=$(str_len "$body")

    info 'http response: %s %s - %s' "$status" "$reason" "$dir"


    # Note: command substitution strips trailing newlines
    _http_response_headers "$status" "$reason" \
        'Content-Type: text/plain; charset=utf-8' \
        "Content-Length: $((length + 1))" \
        "$@"

    [ "${method:-}" = "HEAD" ] || printf '%s\n' "$body"
) }

# ------------------------------------------------------------------------------

_get() { (
    path=$1; shift;
    file=$(_path "$path") || return

    if [ -d "$file" ]; then
        case "$path" in
            */) ;;
            *)  http_response_400 "Directories must end with a slash ('/')"
                return ;;
        esac

        list_directory 200 "$file"
        return
    fi

    serve_file 200 "$file"
) }

_post() { (
    path=$1; shift;
    file=$(_path "$path") || return

    case "$path" in
        */) [ -e "$file" ] && {
                debug 'Directory already exists: %s' "$file"
                http_response_409 'Directory already exists'
                return
            }

            mkdir -p "$file" || {
                debug 'Failed to create directory: %s' "$file"
                http_response_500 'Failed to create directory'
                return
            }

            info 'created directory: %s' "$file"
            http_response_empty 201
            ;;
        *)  [ -e "$file" ] && {
                debug 'File already exists: %s' "$file"
                http_response_409 'File already exists'
                return
            }

            _write_file
            ;;
    esac
) }

_put() { (
    path=$1; shift;
    file=$(_path "$path") || return

    [ -f "$file" ] || {
        http_response_404 'File not found'
        return
    }

    _write_file
) }

_delete() { (
    path=$1; shift;
    file=$(_path "$path") || return

    if [ -d "$file" ]; then
        rmdir "$file" 2>/dev/null || {
            debug 'Directory is not empty: %s' "$file"
            http_response_409 'Directory is not empty'
            return
        }

        info 'deleted directory: %s' "$file"
        http_response_204
        return
    fi

    [ -f "$file" ] || { http_response_404; return; }

    rm "$file" || {
        debug 'Failed to delete file: %s' "$file"
        http_response_500 "Failed to delete file"
        return
    }

    info 'deleted file: %s' "$file"
        http_response_204
) }

# ------------------------------------------------------------------------------

_path() { (
    path=$1; shift;
    path="${path%%\?*}"

    case "$path" in
        /*) ;;
        *)  http_response_400 "Path must start with slash ('/')"; return 1 ;;
    esac

    case "$path" in
        */../*|*/..)
            debug 'Invalid path: %s' "$path"
            http_response_400 "Path can't contain '..'"
            return 1
            ;;
    esac

    printf '%s' "${SHARE_ROOT}${path}"

    return 0
) }

_write_file() { (
    parent=${file%/*}

    [ -d "$parent" ] || {
        info 'Parent directory does not exist: %s' "$parent"
        http_response_404 'Parent directory does not exist'
        return
    }

    [ -n "${req_content_length:-}" ] || { http_response_411; return; }

    case "${req_content_length:-}" in
        *[!0-9]*)
            info "Invalid Content-Length: '%s'" "${req_content_length:-}"
            http_response_400 'Invalid Content-Length'
            return
            ;;
    esac

    existed=false
    [ -f "$file" ] && existed=true

    # TODO: we read on blocks of 1, that works but... it can be improved
    dd bs=1 count="$req_content_length" > "$file" 2>/dev/null || {
        error 'Failed to write file: %s' "$file"
        http_response_500 'Failed to write file'
        return
    }

    if [ "$existed" = true ]; then
        info 'replaced file: %s' "$file"
        http_response_204
    else
        info 'created file: %s' "$file"
        http_response_empty 201
    fi
) }

# ------------------------------------------------------------------------------

case "$SHARE_ROOT" in
    */) error "\$SHARE_ROOT can't end with slash ('/'): %s" "$SHARE_ROOT"
        http_response_500 'Server config error'
        exit 1
        ;;
esac

[ -d "$SHARE_ROOT" ] || {
    error "\$SHARE_ROOT must be a existing directory: %s" "$SHARE_ROOT"
        http_response_500 'Server config error'
    exit 1
}

serve
