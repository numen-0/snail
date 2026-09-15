#!/bin/sh

[ "${__LOG_SH_LOADED__:-}" ] && return
__LOG_SH_LOADED__=1

: "${LOG_NAME:=logger}"
: "${LOG_LEVEL:=INFO}"
: "${LOG_FMT:=str}"
: "${LOG_FILE:=/dev/null}"
: "${LOG_COLOR:=true}"

: "${LOG_C_RESET:=$(printf '\033[0m')}"
: "${LOG_C_DEBUG:=$(printf '\033[1;7;36m')}"
: "${LOG_C_INFO:=$(printf '\033[1;7;92m')}"
: "${LOG_C_WARN:=$(printf '\033[1;7;33m')}"
: "${LOG_C_ERROR:=$(printf '\033[1;7;31m')}"

if ! (return 2>/dev/null); then
    cat <<DOCS
API:
        debug   fmt [arg...]
        info    fmt [arg...]
        warn    fmt [arg...]
        error   fmt [arg...]

ENV:
        LOG_LEVEL   : DEBUG | INFO | WARN | ERROR = '$LOG_LEVEL'
        LOG_FMT     : str | json                  = '$LOG_FMT'
        LOG_FILE    : <file>                      = '$LOG_FILE'
        LOG_NAME    : <name>                      = '$LOG_NAME'
        LOG_COLOR   : true | false                = '$LOG_COLOR'

        $(printf "LOG_C_DEBUG : %-27s = $LOG_C_DEBUG debug $LOG_C_RESET" str)
        $(printf "LOG_C_INFO  : %-27s = $LOG_C_INFO info $LOG_C_RESET" str)
        $(printf "LOG_C_WARN  : %-27s = $LOG_C_WARN warn $LOG_C_RESET" str)
        $(printf "LOG_C_ERROR : %-27s = $LOG_C_ERROR error $LOG_C_RESET" str)

NOTES:
        - Logs are written to stderr (and \$LOG_FILE if configured), so stdout
          can safely be used as a data channel while stderr acts as a side
          channel for diagnostics.
DOCS
    exit 0
fi

# - api ------------------------------------------------------------------------

debug()  { _log DEBUG "$(printf "$@")"; }
info()   { _log INFO  "$(printf "$@")"; }
warn()   { _log WARN  "$(printf "$@")"; }
error()  { _log ERROR "$(printf "$@")"; }

# - helpers --------------------------------------------------------------------

_log_date() { date '+%Y-%m-%dT%H:%M:%S%z'; }
[ -n "$LOG_FILE" ] \
    && _log_out() { tee -a "$LOG_FILE" >&2; } \
    || _log_out() { cat >&2; }

if [ "$LOG_FMT" = "str" ]; then
    [ "$LOG_COLOR" = "true" ] \
        && _log() {
            level=$1; shift;
            msg=$(printf "$@")

            case "$level" in
                DEBUG) fmt="%s $LOG_C_DEBUG DEBUG $LOG_C_RESET %-8s : %s\n";;
                INFO)  fmt="%s $LOG_C_INFO INFO $LOG_C_RESET  %-8s : %s\n";;
                WARN)  fmt="%s $LOG_C_WARN WARN $LOG_C_RESET  %-8s : %s\n";;
                ERROR) fmt="%s $LOG_C_ERROR ERROR $LOG_C_RESET %-8s : %s\n";;
                *)     fmt="%s $level %12s %s\n" ;;
            esac

            printf \
                "$fmt" \
                "$(_log_date)" \
                "$LOG_NAME" \
                "$msg" \
                | _log_out
        } || _log() {
            level=$1; shift;
            msg=$(printf "$@")

            printf \
                "%s %5s %12s %s\n" \
                "$(_log_date)" \
                "$level" \
                "$LOG_NAME" \
                "$msg" \
                | _log_out
        }
elif [ "$LOG_FMT" = "json" ]; then
    _log() {
        level=$1; shift;
        msg=$(printf "%s" "$@")

        jq -cn \
            --arg time "$(_log_date)" \
            --arg level "$level" \
            --arg logger "$LOG_NAME" \
            --arg msg "$msg" \
            '{time: $time, level: $level, logger: $logger, msg: $msg}' \
            | _log_out
    }
else
    echo "log.sh: unknwon \$LOG_FMT: '$LOG_FMT'" >&2; exit 1
fi


case "$LOG_LEVEL" in
    DEBUG)  : ;;
    INFO)   debug() { :; } ;;
    WARN)   debug() { :; }
            info()  { :; } ;;
    ERROR)  debug() { :; }
            info()  { :; }
            warn()  { :; } ;;
    *)      echo "log.sh: unknown \$LOG_LEVEL: '$LOG_LEVEL'" >&2; exit 1 ;;
esac

