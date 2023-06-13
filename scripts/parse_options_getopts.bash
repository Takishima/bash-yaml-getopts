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

[ "${_sourced_parse_options}" != "" ] && return || _sourced_parse_options=.
[ "${BASH_SOURCE[0]}" -ef "$0" ] && echo "$0 should not be executed, only sourced" >&2 && exit 1

BASEPATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}" )" &> /dev/null && pwd )

. "$BASEPATH/options_common.bash"

# ==============================================================================

function no_arg() {
    declare -g OPT
    [ -z "$OPTARG" ] || LOG_FATAL "No arg allowed for --$OPT option"
}

function needs_arg() {
    declare -g OPT OPTARG flag_value
    [ -n "$OPTARG" ] || LOG_FATAL "Missing arg for -$OPT/--$OPT option"
    [ "$flag_value" -ne 0 ] || LOG_FATAL "Cannot specify --no-$OPT for non-flag argument --$OPT"
}

# ==============================================================================

function parse_args() {
    declare -i has_extra_args=0
    local getopts_args

    add_default_options
    getopts_args="$(generate_getopts_args)-:"
    LOG_DEBUG "getopts_args = ${getopts_args}"

    if command -v parse_extra_args >/dev/null 2>&1; then
        has_extra_args=1
        getopts_args="${getopts_args_extra:-}${getopts_args}"
    fi

    declare -g OPT OPTARG flag_value

    while getopts "${getopts_args}" OPT; do
        # shellcheck disable=SC2214,SC2295
        if [ "$OPT" = "-" ]; then     # long option: reformulate OPT and OPTARG
            OPT="${OPTARG%%=*}"       # extract long option name
            OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
            OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
        fi
        LOG_DEBUG "Processing: $OPT $OPTARG"

        if [ "$OPT" == '?' ]; then
            # bad short option (error reported via getopts)
            exit 2
        fi

        process_option "$OPT" "$OPTARG"

        if [ -n "${parameters_short_to_long[$OPT]}" ]; then
            declare -n parameters_attributes="parameters_${parameters_short_to_long[$OPT]}"
        else
            declare -n parameters_attributes="parameters_${OPT//-/_}"
        fi

        var_type="${parameters_attributes[type]:-delegated}"
        var_name="${parameters_attributes[var_name]:-dummy_var}"

        if [ "$var_type" != "delegated" ]; then
            if [[ "$var_type" != 'bool' && "$var_type" != 'help' ]]; then
                needs_arg
            else
                no_arg
            fi
        fi
    done

    handle_default_options
    handle_log_level_option
}
