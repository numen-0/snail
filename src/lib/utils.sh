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
