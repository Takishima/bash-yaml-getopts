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
. "$BASEPATH/getopts_long.bash"

# ==============================================================================

function generate_long_args() {
    declare -ga __long_args=()

    for __param_name in "${parameters_names[@]}"; do
        declare -n __param_attributes="parameters_${__param_name}"
        __long_args+=("${__param_attributes[long_option]}")
        if [[ "${__param_attributes[type]}" == bool || "${__param_attributes[type]}" == help ]]; then
            __long_args+=(no_argument)

            if [[ "${__param_attributes[type]}" == bool ]]; then
                __long_args+=("no-${__param_attributes[long_option]}")
                __long_args+=(no_argument)
            fi
        else
            __long_args+=(required_argument)
        fi
    done
}

# ==============================================================================

function parse_args() {
    local __getopts_args
    declare -i __has_extra_args=0

    add_default_options
    __getopts_args="$(generate_getopts_args)"
    LOG_DEBUG "getopts_args = ${__getopts_args}"

    if command -v parse_extra_args >/dev/null 2>&1; then
        __has_extra_args=1
        __getopts_args="${getopts_args_extra:-}${__getopts_args}"
    fi

    declare -g OPT OPTLARG
    declare -ga __long_args

    generate_long_args || LOG_FATAL "Failed to generate list of long arguments"
    LOG_DEBUG "__long_args = $(variable_to_string __long_args)"

    OPTLIND=1
    while getopts_long ":${__getopts_args}" OPT "${__long_args[@]}" "" "$@"; do
        LOG_DEBUG "Processing: $OPT $OPTLARG"

        if [[ "$OPT" == ':' && "$__has_extra_args" -ne 1 ]]; then
            LOG_FATAL "$OPTLERR"
        fi

        process_option "$OPT" "$OPTLARG"
    done

    handle_default_options
    handle_log_level_option
}
