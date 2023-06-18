# Copyright 2023 Damien Nguyen <ngn.damien@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# Fail on error
set -o errexit

# ==============================================================================

[ "${_sourced_config}" != "" ] && return || _sourced_config=.
[ "${BASH_SOURCE[0]}" -ef "$0" ] && echo "$0 should not be executed, only sourced" >&2 && exit 1

# ==============================================================================

ncolors=$(tput colors 2> /dev/null)
if [[ -n "$ncolors" && "$ncolors" -ge 16 ]]; then
    _BOLD="$(tput bold)"
    _UNDERLINE="$(tput smul)"
    _STANDOUT="$(tput smso)"
    _NORMAL="$(tput sgr0)"
    _BLACK="$(tput setaf 0)"
    _RED="$(tput setaf 1)"
    _GREEN="$(tput setaf 2)"
    _YELLOW="$(tput setaf 3)"
    _BLUE="$(tput setaf 4)"
    _MAGENTA="$(tput setaf 5)"
    _CYAN="$(tput setaf 6)"
    _WHITE="$(tput setaf 7)"
    _GREY="$(tput setaf 8)"
fi
unset ncolors

# ==============================================================================

declare -A _LOG_LEVELS=([FATAL]=1    # Fatal log level. Cause exit failure
                        [WARN]=2     # Warning log level
                        [INFO]=3     # Informational log level
                        [DEBUG]=4    # Debug log level
                        [SILENT]=10) # Silent log level
# Inverse mapping
declare -A _FROM_LOG_LEVEL=([1]=FATAL
                            [2]=WARN
                            [3]=INFO
                            [4]=DEBUG
                            [10]=SILENT)
declare -A _LOG_LEVEL_PREFIXES=([FATAL]="${_RED}"
                                [WARN]="${_YELLOW}"
                                [INFO]="${_WHITE}"
                                [DEBUG]="${_BLUE}")

# Default log level
: "${LOG_LEVEL:=${LOGLEVEL:-}}"
: "${LOG_LEVEL:=${_LOG_LEVELS[INFO]}}}"

# Compatibility for setting LOG_LEVEL to a string (e.g. LOG_LEVEL=debug)
if [ -n "${_LOG_LEVELS[${LOG_LEVEL^^}]}" ]; then
    LOG_LEVEL="${_LOG_LEVELS[${LOG_LEVEL^^}]}"
fi

[[ ! "$LOG_LEVEL" =~ [0-9]+ ]] && echo "Invalid LOG_LEVEL value: $LOG_LEVEL" && exit 1

# Print log message
# _log_print_message <level> <msg>
_log_print_message() {
    local level_name=${1^^} level="${_LOG_LEVELS[${1^^}]:-${_LOG_LEVELS[FATAL]}}"
    shift
    local log_message="${*:-}"

    if [ "$LOG_LEVEL" -eq "${_LOG_LEVELS[SILENT]:-0}" ] || [ "$level" -gt "$LOG_LEVEL" ]; then
        return 0
    fi

    printf '%b[%-5s] %b%b\n' "${_LOG_LEVEL_PREFIXES[$level_name]}" "$level_name" "$log_message" "${_NORMAL}"
}

LOG_FATAL() { _log_print_message FATAL "$1" >&2; exit 1; }
LOG_FATAL_INTERNAL() { LOG_FATAL "[internal] $1"; }
LOG_WARN()  { _log_print_message WARN "$1" >&2; }
LOG_INFO()  { _log_print_message INFO "$1" >&2; }
LOG_DEBUG() { _log_print_message DEBUG "$1" >&2; }

# ==============================================================================

# locate_cmd <var_name> <name1> ... <nameN>
locate_cmd() {
    local var_name="$1"
    shift

    if [ -n "${!var_name}" ]; then
        LOG_DEBUG "${var_name}=${!var_name} already defined, exiting..."
        return 0
    fi

    for name in "$@"; do
        if command -v "$name" > /dev/null 2>&1; then
            cmd_name="$(command -v "$name")"
            LOG_DEBUG "Command '$name' found at '$cmd_name'"
            break
        fi
    done

    if [ -n "$cmd_name" ]; then
        declare -gr "$var_name=$cmd_name"
        return 0
    else
        LOG_FATAL "None of '$*' commands found"
        return 1
    fi
}

# ==============================================================================

verify_system() {
    declare -g PARAM_YAML_CONFIG

    [ "${BASH_VERSINFO[0]}" -ge 4 ] || echo "Associative arrays require Bash>=4.x (you have: $BASH_VERSION)"
    [ -n "${PARAM_YAML_CONFIG}" ] || LOG_FATAL "Variable 'PARAM_YAML_CONFIG' not defined!"
    [ -r "${PARAM_YAML_CONFIG}" ] || LOG_FATAL "YAML config file '$PARAM_YAML_CONFIG' not readable"
}

# ==============================================================================

variable_to_string() {
    set -o posix
    set_output=$(set)
    re=$'\n'"(${1}=[^"$'\n'"]+)" && [[ "$set_output" =~ $re ]] && echo "${BASH_REMATCH[1]}"
}

# ==============================================================================
