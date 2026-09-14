#!/bin/sh

[ "${__HTTP_SH_LOADED__:-}" ] && return
__HTTP_SH_LOADED__=1

. "${ROOT_DIR:-.}/src/log.sh"

HTTP_SERVER="snailHTTP/0.1.0"
: "${HTTP_HOST:=localhost}"

if ! (return 2>/dev/null); then
    cat <<DOCS
API:
   res> http_server             >req        port handler

  body> http_response           >res        status [key: value]...
        http_response_empty     >res        status [key: value]...

        http_response_200       >res        [msg]
        http_response_303       >res        location [msg]
        http_response_400       >res        [msg]
        http_response_404       >res        [msg]
        http_response_405       >res        [msg]
        http_response_418       >res        [msg]
        http_response_500       >res        [msg]
        http_response_505       >res        [msg]

ENV:
        HTTP_HOST       : <host>      = '$HTTP_HOST'

NOTE:
        - Headers must be ASCII printable or spaces and match the next regex:
          "^[^:']\\+: [^']\\+$"
DOCS
    exit 0
fi

# - server ---------------------------------------------------------------------

http_server() { (
    port="$1"; handler="$2"; shift 2;
    fifo="${TMPDIR:-/tmp}/http.$PPID.$port.fifo"

    rm -f "$fifo"
    mkfifo "$fifo"
    trap 'rm -f "$fifo"' 0

    info 'Starting http server %s\n' "$HTTP_SERVER"
    info 'Listening on http://%s:%s\n' "$HTTP_HOST" "$port"

    while true; do
        cat "$fifo" |
            nc -lk -p "$port" -e "$handler"
    done
) }

# - response -------------------------------------------------------------------

http_response() { (
    status=$1; shift;

    _validate_status "$status" && _validate_headers "$@" || {
        http_response_500
        return
    }

    reason=$(_http_reason "$status")
    body=$(cat)
    length=$(_length "$body")

    info 'http response: %s %s' "$status" "$reason" "$body"

    _http_response_headers "$status" "$reason" \
        "Content-Length: $length" \
        "$@"
    printf '%s' "$body"
) }

http_response_empty() { (
    status=$1; shift;

    _validate_status "$status" && _validate_headers "$@" || {
        http_response_500
        return
    }

    reason=$(_http_reason "$status")

    info 'http response: %s %s' "$status" "$reason"

    _http_response_headers "$status" "$reason" "$@"
) }

http_response_200() { _http_response 200 "${1:-'OK'}"; }
http_response_303() { _http_response 303 "${2:-'See Other'}" "Location: $1"; }
http_response_400() { _http_response 400 "${1:-'Bad Request'}"; }
http_response_404() { _http_response 404 "${1:-'Not Found'}"; }
http_response_405() { _http_response 405 "${1:-'Method Not Allowed'}"; }
http_response_418() { _http_response 418 "${1:-"I'm a teapot"}"; }
http_response_500() { _http_response 500 "${1:-'Internal Server Error'}"; }
http_response_505() { _http_response 505 "${1:-'HTTP Version Not Supported'}"; }

# - helpers --------------------------------------------------------------------

_http_response_headers() { (
    status=$1; reason=$2; shift 2;

    printf 'HTTP/1.1 %s %s\r\n' "$status" "$reason"
    printf 'Server: %s\r\n' "$HTTP_SERVER"

    while [ "$#" -gt 0 ]; do
        printf '%s\r\n' "$1"; shift;
    done

    printf 'Connection: close\r\n'
    printf '\r\n'
) }

_http_response() { (
    status=$1; msg=${2:-}; shift 2;
    printf '%s' "$msg" |
        http_response "$status" \
            "Content-Type: text/plain; charset=utf-8" \
            "$@"
) }

_validate_status() {
    case "$1" in
        100|101|102|200|201|202|203|204|205|206|300|301|302|303|304|307|308|400|401|402|403|404|405|406|407|408|409|410|411|412|413|414|415|416|417|418|421|422|423|424|425|426|428|429|431|451|500|501|502|503|504|505|506|507|508|510|511)
            return 0 ;;
        *)  error 'invalid HTTP status: %s' "$1"
            return 1 ;;
    esac
}

_validate_headers() {
    # Note: This validation is intentionally not strict. It only ensures that
    #       headers follow the `key: value` format and only contain printable
    #       ASCII or spaces.

    while [ "$#" -gt 0 ]; do

        _is_printable_ascii "$1" \
            && printf '%s' "$1" \
            | grep -q "^[^:']\+: [^']\+$" || {
            error 'invalid HTTP header: %s' "$1"
            return 1
        }

        shift;
    done

    return 0
}

_is_printable_ascii() {
    LC_ALL=C
    case "$1" in
        *[![:space:][:print:]]*) return 1 ;;
        *) return 0 ;;
    esac
}

_http_reason() {
    case "$1" in
        200) printf '%s' 'OK' ;;
        303) printf '%s' 'See Other' ;;
        304) printf '%s' 'Not Modified' ;;
        400) printf '%s' 'Bad Request' ;;
        404) printf '%s' 'Not Found' ;;
        405) printf '%s' 'Method Not Allowed' ;;
        418) printf '%s' "I'm a teapot" ;;
        500) printf '%s' 'Internal Server Error' ;;
        505) printf '%s' 'HTTP Version Not Supported' ;;
        *)   printf '%s' 'Unknown' ;;
    esac
}

_length() { printf '%s' "$1" | wc -c; }

