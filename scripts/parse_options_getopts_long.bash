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
    declare -ga long_args=()

    for param_name in "${parameters_names[@]}"; do
        declare -n parameters_attributes="parameters_${param_name}"
        long_args+=("${parameters_attributes[long_option]}")
        if [[ "${parameters_attributes[type]}" == bool || "${parameters_attributes[type]}" == help ]]; then
            long_args+=(no_argument)

            if [[ "${parameters_attributes[type]}" == bool ]]; then
                long_args+=("no-${parameters_attributes[long_option]}")
                long_args+=(no_argument)
            fi
        else
            long_args+=(required_argument)
        fi
    done
}

# ==============================================================================

function parse_args() {
    declare -i has_extra_args=0
    local getopts_args

    add_default_options
    getopts_args="$(generate_getopts_args)"
    LOG_DEBUG "getopts_args = ${getopts_args}"

    if command -v parse_extra_args >/dev/null 2>&1; then
        has_extra_args=1
        getopts_args="${getopts_args_extra:-}${getopts_args}"
    fi

    declare -g OPT OPTLARG
    declare -ga long_args

    generate_long_args || LOG_FATAL "Failed to generate list of long arguments"
    LOG_DEBUG "long_args = $(variable_to_string long_args)"

    OPTLIND=1
    while getopts_long ":${getopts_args}" OPT "${long_args[@]}" "" "$@"; do
        LOG_DEBUG "Processing: $OPT $OPTLARG"

        if [ "$OPT" == ':' ]; then
            LOG_FATAL "$OPTLERR"
        fi

        process_option "$OPT" "$OPTLARG"
    done

    for param_name in "${parameters_names[@]}"; do
        declare -n parameters_attributes="parameters_${param_name}" var_was_set="_${param_name}_was_set"
        if [[ "${var_was_set:-0}" == "0" && -n "${parameters_attributes[default]}" ]]; then
            set_var "${parameters_attributes[var_name]}" "${parameters_attributes[default]}"
        fi
    done

    # ==========================================================================
    # Handle default options

    declare -g LOG_LEVEL
    declare -gr _LOG_LEVELS _log_level_was_set log_level

    if  [ "${_log_level_was_set:-0}" -eq 1 ]; then
        _level="${_LOG_LEVELS[${log_level^^}]}"
        # shellcheck disable=SC2034
        [ -n "$_level" ] || LOG_FATAL "Value '$log_level' for argument '--log-level' is invalid" && LOG_LEVEL="$_level"
    fi
}
