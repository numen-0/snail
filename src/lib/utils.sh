#!/bin/sh

[ "${__UTILS_SH_LOADED__:-}" ] && return
__UTILS_SH_LOADED__=1

if ! (return 2>/dev/null); then
    cat <<DOCS
API:
        file_etag               >etag       file
        file_content_type       >ct         file

        str_len                 >len        str
        str_lower               >len        str
        str_is_printable_ascii  0|1         str

        fmt_bytes_to_human      >str        num
        fmt_number              >str        num
DOCS
    exit 0
fi

# ------------------------------------------------------------------------------

str_len() { printf '%s' "$1" | wc -c; }
str_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

str_is_printable_ascii() {
    LC_ALL=C
    case "$1" in
        *[![:space:][:print:]]*) return 1 ;;
        *) return 0 ;;
    esac
}

file_etag() { cksum "$1" | cut -d ' ' -f 1; }

file_content_type() {
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

fmt_bytes_to_human() {
    if [ "$1" -lt 1024 ]; then
        printf '%sb' "$1"
    elif [ "$1" -lt 1048576 ]; then
        printf '%s.%sKiB' \
            "$(( $1 / 1024 ))" \
            "$(( ($1 % 1024) * 10 / 1024 ))"
    elif [ "$1" -lt $((1073741824)) ]; then
        printf '%s.%sMiB' \
            "$(( $1 / 1048576 ))" \
            "$(( ($1 % 1048576) * 10 / 1048576 ))"
    else
        printf '%s.%sGiB' \
            "$(( $1 / 1073741824 ))" \
            "$(( ($1 % 1073741824) * 10 / 1073741824 ))"
    fi
}

fmt_number() {
    printf '%s\n' "$1" |
        sed ':a;s/\([0-9]\)\([0-9][0-9][0-9]\)\(\.[0-9]*\)*$/\1.\2\3/;ta'
}
