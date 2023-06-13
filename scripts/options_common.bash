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
    local name=$1 value=$2
    shift 2

    local eval_str="$name" value_lower=${value,,}

    if [[ ${value_lower} =~ ^(yes|true)$ ]]; then
        eval_str="$eval_str=1"
    elif [[ ${value_lower} =~ ^(no|false)$ ]]; then
        eval_str="$eval_str=0"
    elif [[ ${value_lower} =~ ^[0-9]+$ ]]; then
        eval_str="$eval_str=$value"
    elif [[ ${value_lower} =~ \"\ \" ]]; then
        # NB: support for arrays
        eval_str="$eval_str=( $value )"
    else
        eval_str="$eval_str=\"$value\""
    fi

    LOG_DEBUG "$eval_str"
    eval "$eval_str"
}

function set_var() {
    local name value

    name=$1
    shift
    value=${1:-1}

    assign_value "$name" "$value"
    assign_value "_${name}_was_set" 1
}

# ==============================================================================

function add_default_options() {
    local default_log_level="${_FROM_LOG_LEVEL[$LOG_LEVEL]:-$LOG_LEVEL_INFO}"
    declare -g parameters_names

    parameters_names=('help' 'log_level' "${parameters_names[@]}")

    # shellcheck disable=SC2034
    declare -gA parameters_help=([short_option]=h
                                 [long_option]=help
                                 [type]=help
                                 [help]='Show this help message and exit')

    log_level_help=$(cat <<EOF
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
                                      [default]="${default_log_level,,}"
                                      [help]="$log_level_help")
}


# ==============================================================================

function generate_getopts_args() {
    local getopts_args=''
    # shellcheck disable=SC2154
    for param_name in "${parameters_names[@]}"; do
        declare -n parameters_attributes="parameters_${param_name}"
        if [ -n "${parameters_attributes[short_option]}" ]; then
            getopts_args="${getopts_args}${parameters_attributes[short_option]}"
            if [[ "${parameters_attributes[type]}" != 'help'  && "${parameters_attributes[type]}" != 'bool' ]]; then
                getopts_args="${getopts_args}:"
            fi
        fi
    done > /dev/null 2> /dev/null
    echo "${getopts_args}-:"
}


# ==============================================================================

function generate_help_message() {
    local PROGRAM=${PROGRAM:-$0}
    declare -a description_lines

    if command -v help_header > /dev/null 2>&1; then
        help_header
    fi

    echo -e '\nUsage:'
    echo "  $PROGRAM [options]"
    echo -e '\nOptions:'

    local help_lines_optnames=() help_lines_description=() optnames_column_width=15
    for param_name in "${parameters_names[@]}"; do
        # shellcheck disable=SC2178
        declare -n parameters_attributes="parameters_${param_name//-/_}"
        if [ -n "${parameters_attributes[short_option]}" ]; then
            help_lines_optnames+=("-${parameters_attributes[short_option]},--${parameters_attributes[long_option]}")
        else
            help_lines_optnames+=("--${parameters_attributes[long_option]}")
        fi
        if [ "$optnames_column_width" -lt "${#help_lines_optnames[-1]}" ]; then
            optnames_column_width="${#help_lines_optnames[-1]}"
        fi

        [ -n "${parameters_attributes[help]}" ] || LOG_FATAL "Missing description string for $param_name"
        readarray -t description_lines  <<<"${parameters_attributes[help]}"

        help_lines_description+=("${description_lines[0]}")
        if [[ -n "${parameters_attributes[default]}" && "${parameters_attributes[type]}" != 'bool' ]]; then
            help_lines_optnames+=('')
            help_lines_description+=("Default value: ${parameters_attributes[default]}")
        fi

        for (( i=1; i<${#description_lines[*]}; i++ )); do
            help_lines_optnames+=('')
            help_lines_description+=("${description_lines[$i]}")
        done
    done

    for (( i=0; i<${#help_lines_optnames[*]}; i++ )); do
        printf "  %-${optnames_column_width}s  %s\n" "${help_lines_optnames[$i]}" "${help_lines_description[$i]}"
    done

    if command -v help_footer >/dev/null 2>&1; then
        help_footer
    fi
}

# ==============================================================================
