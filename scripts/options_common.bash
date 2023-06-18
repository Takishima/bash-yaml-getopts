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

[ "${_sourced_options_common}" != "" ] && return || _sourced_options_common=.

[ "${BASH_SOURCE[0]}" -ef "$0" ] && echo "$0 should not be executed, only sourced" >&2 && exit 1

# ==============================================================================

function assign_value() {
    local __name=$1 __value=$2
    shift 2

    local __eval_str="$__name" __value_lower=${__value,,}

    if [[ ${__value_lower} =~ ^(yes|true)$ ]]; then
        __eval_str="$__eval_str=1"
    elif [[ ${__value_lower} =~ ^(no|false)$ ]]; then
        __eval_str="$__eval_str=0"
    elif [[ ${__value_lower} =~ ^[0-9]+$ ]]; then
        __eval_str="$__eval_str=$__value"
    elif [[ ${__value_lower} =~ \"\ \" ]]; then
        # NB: support for arrays
        __eval_str="$__eval_str=( $__value )"
    else
        __eval_str="$__eval_str=\"$__value\""
    fi

    LOG_DEBUG "$__eval_str"
    eval "$__eval_str"
}

function set_var() {
    local __name __value

    __name=$1
    shift
    __value=${1:-1}

    assign_value "$__name" "$__value"
    assign_value "_${__name}_was_set" 1
}

# ==============================================================================

function add_default_options() {
    local __default_log_level="${_FROM_LOG_LEVEL[$LOG_LEVEL]:-$LOG_LEVEL_INFO}"
    local __log_level_help
    declare -g parameters_names

    parameters_names=('help' 'log_level' "${parameters_names[@]}")

    # shellcheck disable=SC2034
    declare -gA parameters_help=([short_option]=h
                                 [long_option]=help
                                 [type]=help
                                 [help]='Show this help message and exit')

    __log_level_help=$(cat <<EOF
Bash logger level
Values:
  fatal    Fatal level
  warn     Warning level
  info     Informational level
  debug    Debug level
  silent   Silent level (ie. disable output)
EOF
                  )
    # shellcheck disable=SC2034
    declare -gA parameters_log_level=([long_option]=log-level
                                      [type]=string
                                      [var_name]=log_level
                                      [default]="${__default_log_level,,}"
                                      [help]="$__log_level_help")
}


# ==============================================================================

function generate_getopts_args() {
    local __getopts_args=''
    # shellcheck disable=SC2154
    for __param_name in "${parameters_names[@]}"; do
        declare -n __param_attributes="parameters_${__param_name}"
        if [ -n "${__param_attributes[short_option]}" ]; then
            __getopts_args="${__getopts_args}${__param_attributes[short_option]}"
            if [[ "${__param_attributes[type]}" != 'help'  && "${__param_attributes[type]}" != 'bool' ]]; then
                __getopts_args="${__getopts_args}:"
            fi
        fi
    done > /dev/null 2> /dev/null
    echo "${__getopts_args}"
}


# ==============================================================================

function generate_help_message() {
    local PROGRAM=${PROGRAM:-$0}
    declare -a __descr_lines

    if command -v help_header > /dev/null 2>&1; then
        help_header
    fi

    echo -e '\nUsage:'
    echo "  $PROGRAM [options]"
    echo -e '\nOptions:'

    local __help_lines_optnames=() __help_lines_description=() __optnames_col_width=15
    for __param_name in "${parameters_names[@]}"; do
        # shellcheck disable=SC2178
        declare -n __param_attributes="parameters_${__param_name//-/_}"
        if [ -n "${__param_attributes[short_option]}" ]; then
            __help_lines_optnames+=("-${__param_attributes[short_option]},--${__param_attributes[long_option]}")
        else
            __help_lines_optnames+=("--${__param_attributes[long_option]}")
        fi
        if [ "$__optnames_col_width" -lt "${#__help_lines_optnames[-1]}" ]; then
            __optnames_col_width="${#__help_lines_optnames[-1]}"
        fi

        [ -n "${__param_attributes[help]}" ] || LOG_FATAL "Missing description string for $__param_name"
        readarray -t __descr_lines  <<<"${__param_attributes[help]}"

        __help_lines_description+=("${__descr_lines[0]}")
        if [[ -n "${__param_attributes[default]}" && "${__param_attributes[type]}" != 'bool' ]]; then
            __help_lines_optnames+=('')
            __help_lines_description+=("Default value: ${__param_attributes[default]}")
        fi

        for (( i=1; i<${#__descr_lines[*]}; i++ )); do
            __help_lines_optnames+=('')
            __help_lines_description+=("${__descr_lines[$i]}")
        done
    done

    for (( i=0; i<${#__help_lines_optnames[*]}; i++ )); do
        printf "  %-${__optnames_col_width}s  %s\n" "${__help_lines_optnames[$i]}" "${__help_lines_description[$i]}"
    done

    if command -v help_footer >/dev/null 2>&1; then
        help_footer
    fi
}

# ==============================================================================

function process_option() {
    local OPT="$1" OPTARG="$2"
    declare -i __has_extra_args=0
    declare -g parameters_short_to_long
    if command -v parse_extra_args >/dev/null 2>&1; then
        __has_extra_args=1
    fi

    # Support specifying --no-XXX to negate a boolean parameter
    __flag_value=1
    if [[ $OPT =~ ^no-([a-zA-Z0-9_-]+) ]]; then
        OPT="${BASH_REMATCH[1]}"
        __flag_value=0
    fi

    if [ -n "${parameters_short_to_long[$OPT]}" ]; then
        declare -n __param_attributes="parameters_${parameters_short_to_long[$OPT]}"
    else
        __tmp="${OPT//-/_}"
        __tmp="parameters_${__tmp//:/_}"
        if [ -z ${!__tmp+x} ]; then
            declare -n __param_attributes="$__tmp"
        fi
    fi

    __var_type="${__param_attributes[type]:-delegated}"
    __var_name="${__param_attributes[var_name]:-dummy_var}"

    LOG_DEBUG "__var_type=$__var_type __var_name=$__var_name __flag_value=$__flag_value"

    case "$__var_type" in
        help)           generate_help_message
                        exit 0
                        ;;
        bool)           set_var "$__var_name" "$__flag_value"
                        ;;
        int )           [[ "$OPTARG" =~ ^[[:digit:]]+$ ]] \
                            || LOG_FATAL "-$OPT/--$OPT requires an integer. Got: '$OPTARG'"
                        ;&
        string )        set_var "$__var_name" "$OPTARG"
                        ;;
        path)           [ -e "$OPTARG" ] || LOG_FATAL "-$OPT/--$OPT requires a valid path! Passed: $OPTARG"
                        set_var "$__var_name" "$OPTARG"
                        ;;
        delegated )     __success=1
                        if [ "$__has_extra_args" -eq 1 ]; then
                            LOG_DEBUG "calling parse_extra_args '$OPT' '$OPTARG' '$__flag_value'"
                            parse_extra_args "$OPT" "$OPTARG" "$__flag_value" && __success=0 || __success=$?
                        fi

                        if [ "$__success" -ne 0 ]; then
                            [ "$__flag_value" -eq 1 ] \
                                || LOG_FATAL "No option found for -$OPT/--$OPT (received --no-$OPT on cmdline)" \
                                    && LOG_FATAL "Illegal option: -$OPT/--$OPT"
                        fi
                        ;;
        * )             LOG_FATAL "Unknown variable type: $__var_type"
                        ;;
    esac
}

# ==============================================================================

function handle_default_options() {
    declare -g parameters_names
    for __param_name in "${parameters_names[@]}"; do
        declare -n __param_attributes="parameters_${__param_name}" var_was_set="_${__param_name}_was_set"
        if [[ "${var_was_set:-0}" == "0" && -n "${__param_attributes[default]}" ]]; then
            set_var "${__param_attributes[var_name]}" "${__param_attributes[default]}"
        fi
    done
}

# ------------------------------------------------------------------------------

function handle_log_level_option() {
    declare -g LOG_LEVEL
    declare -gr _LOG_LEVELS _log_level_was_set log_level

    if  [ "${_log_level_was_set:-0}" -eq 1 ]; then
        _level="${_LOG_LEVELS[${log_level^^}]}"
        # shellcheck disable=SC2034
        [ -n "$_level" ] || LOG_FATAL "Value '$log_level' for argument '--log-level' is invalid" && LOG_LEVEL="$_level"
    fi
}

# ==============================================================================
