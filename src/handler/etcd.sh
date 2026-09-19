#!/bin/sh

[ -f .env ] && . ./.env

. "${APP_DIR:-.}/src/lib/log.sh"
. "${APP_DIR:-.}/src/lib/http.sh"
. "${APP_DIR:-.}/src/lib/utils.sh"

: "${ETCD_ROOT:="${APP_DIR:-.}/data/etcd"}"
: "${ETCD_TMP:="/tmp/etcd"}"

ETCD_DATA="${ETCD_ROOT}/data"
ETCD_LOCK="${ETCD_ROOT}/.lock"
ETCD_TRANSACTION="${ETCD_ROOT}/.transaction"

# - api ------------------------------------------------------------------------

_CR="$(printf '\r')"
serve() { (
    IFS=' ' read -r method path protocol || {
        info 'Failed to parse http Start line'
        http_response_400 'Failed to parse http Start line'
        return
    }

    protocol="${protocol%$_CR}"

    info 'request: %s %s %s' "$method" "$path" "$protocol"

    [ "$protocol" = 'HTTP/1.1' ] || {
        info 'HTTP version not supported: %s' "$protocol"
        http_response_505
        return
    }

    req_content_length=""

    while IFS= read -r header; do
        header="${header%$_CR}"

        [ -z "$header" ] && break

        _validate_headers "$header" || {
            http_response_400 "Invalid header: $header"
            return
        }

        case "$(str_lower "$header")" in
            content-length:*)
                req_content_length="${header#*:}"
                req_content_length="${req_content_length#* }"
                req_content_length="${req_content_length%% *}"
                ;;
        esac

        [ "$LOG_LEVEL" = "DEBUG" ] \
            && printf '%s\n' "$header" >&2
    done

    case "$path" in
        /v1/kv|/v1/kv/*) _kv "$method" "${path#/v1/kv}" ;;
        *) http_response_404 ;;
    esac
) }

# - kv -------------------------------------------------------------------------

_kv() { (
    method=$1; key=$2; shift 2;

    case "$key" in
        "") http_response_400 'Key cannot be empty'
            return
            ;;
        /*) ;;
        *)  http_response_400 "Key must start with slash ('/')"
            return
            ;;
    esac

    case "$key" in
        */../*|*/..|../*)
            http_response_400 "Key can't contain '..'"
            return
            ;;
    esac

    case "$method" in
        PUT)      _kv_put "$key" ;;
        GET|HEAD) _kv_get "$key" ;;
        DELETE)   _kv_delete "$key" ;;
        *)        http_response_405 ;;
    esac
) }

_kv_put() { (
    key=$1; shift 1;
    file="${ETCD_DATA}${key}";
    parent=${file%/*}
    tmp="${ETCD_TMP}/value.tmp.$$"

    [ -n "${req_content_length:-}" ] || { http_response_411; return; }

    case "$req_content_length" in
        *[!0-9]*)
            http_response_400 'Invalid Content-Length'
            return
            ;;
    esac

    _lock || { http_response_500 'Failed to lock'; return; }

    # Note: A key cannot be both a value and a prefix for other keys
    [ -f "$parent" ] && {
        _unlock
        http_response_409 'Key has a conflicting parent'
        return
    }; [ -d "$file" ] && {
        _unlock
        http_response_409 'Key is a directory'
        return
    }

    # Note: failing transactions after a bump, burning transaction ids, is
    #       preferable than overlaping transaction ids...
    transaction=$(_next_transaction) || {
        _unlock
        http_response_500 'Failed to update transaction'
        return
    }

    mkdir -p "$parent" || {
        _unlock
        http_response_500 'Failed to create parent directory'
        return
    }

    # TODO: Improve read
    dd bs=1 count="$req_content_length" > "$tmp" 2>/dev/null || {
        _prune_empty_parents "$parent"
        rm -f "$tmp"
        _unlock
        http_response_500 'Failed to write value'
        return
    }

    mv "$tmp" "$file" || {
        _prune_empty_parents "$parent"
        rm -f "$tmp"
        _unlock
        http_response_500 'Failed to commit value'
        return
    }

    value=$(cat "$file") || {
        _unlock
        http_response_500 'Failed to read value'
        return
    }

    _unlock

    info '[%s] PUT %s' "$transaction" "$key"

    body=$(cat <<EOF
$transaction
$key
$value
EOF
)

    _http_response_headers 200 'OK' \
        "Content-Length: $(str_len "$body")"

    printf '%s' "$body"
) }

_kv_get() { (
    key=$1; shift 1;
    file="${ETCD_DATA}${key}";

    _lock || { http_response_500 'Failed to lock'; return; }

    [ -f "$file" ] || { _unlock; http_response_404; return; }

    transaction=$(_get_transaction) || {
        _unlock
        http_response_500 'Failed to read transaction'
        return
    }

    value=$(cat "$file") || {
        _unlock
        http_response_500 'Failed to read value'
        return
    }

    _unlock

    info '[%s] GET %s' "$transaction" "$key"

    body=$(cat <<EOF
$transaction
$key
$value
EOF
)

    _http_response_headers 200 'OK' \
        "Content-Length: $(str_len "$body")"

    [ "${method:-}" = HEAD ] || printf '%s' "$body"
) }

_kv_delete() { (
    key=$1; shift 1;
    file="${ETCD_DATA}${key}";

    _lock || { http_response_500 'Failed to lock'; return; }

    [ -f "$file" ] || { _unlock; http_response_404; return; }

    transaction=$(_next_transaction) || {
        _unlock
        http_response_500 'Failed to update transaction'
        return
    }

    rm "$file" || {
        _unlock
        http_response_500 'Failed to delete value'
        return
    }

    # Note: remove empty dirs so posible future keys can use the path
    _prune_empty_parents "${file%/*}"

    _unlock

    info '[%s] DELETED %s' "$transaction" "$key"

    body=$(cat <<EOF
$transaction
$key
EOF
)

    _http_response_headers 200 'OK' \
        "Content-Length: $(str_len "$body")"

    printf '%s' "$body"
) }

# - locking -------------------------------------------------------------------

_lock() {
    while ! mkdir "$ETCD_LOCK" 2>/dev/null; do
        sleep 0.01
    done
}

_unlock() {
    rmdir "$ETCD_LOCK" 2>/dev/null || true
}

# - transaction ----------------------------------------------------------------

_get_transaction() {
    [ -f "$ETCD_TRANSACTION" ] || { printf '0'; return; }

    cat "$ETCD_TRANSACTION"
}

_next_transaction() { (
    transaction=$(_get_transaction) || return 1
    tmp="${ETCD_TMP}/transaction.tmp.$$"

    case "$transaction" in
        *[!0-9]*)
            error 'Invalid transaction: %s' "$transaction"
            return 1
            ;;
    esac

    transaction=$((transaction + 1))

    printf '%s' "$transaction" > "$tmp" || return 1

    mv "$tmp" "$ETCD_TRANSACTION" || {
        rm -f "$tmp" 2>/dev/null
        return 1
    }

    printf '%s' "$transaction"
) }

_prune_empty_parents() { (
    dir=${1%/}; shift 1;

    while [ "$dir" != "$ETCD_DATA" ]; do
        rmdir "$dir" 2>/dev/null || break
        dir=${dir%/*}
    done
) }

# - init ----------------------------------------------------------------------

mkdir -p "$ETCD_ROOT" "$ETCD_TMP" "$ETCD_DATA" || {
    error '%s' 'Failed to create core directories'
    exit 1
}

[ -f "$ETCD_TRANSACTION" ] || {
    printf '0' > "$ETCD_TRANSACTION" || {
        error 'Failed to initialize transaction'
        exit 1
    }
}

serve
