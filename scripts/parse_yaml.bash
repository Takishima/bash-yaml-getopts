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

[ "${_sourced_parse_yaml}" != "" ] && return || _sourced_parse_yaml=.

BASEPATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
[ "${BASH_SOURCE[0]}" -ef "$0" ] && echo "$0 should not be executed, only sourced" >&2 && exit 1

. "$BASEPATH/config.bash"

# ==============================================================================

# parse_yaml_parameter_file <filename>
#
# Read a list of parameter attributes from a YAML file that is structured as follows:
# parameters:
#   param_name:
#     short_option: <string> (e.g. '-B')
#     help: <string> (e.g. 'Build directory')
#     type: <string> (one of: bool, int, string, path
#     default: <any>
#
# Any parameter attribute may be omitted except `type` (but this might lead to some error messages down the line in
# other functions)
# For each parameter, this function will add the name to an array named `parameter_names` and the parameter attributes
# will be stored in an associative array named `parameters_<param_name>` (e.g. `parameters_build`)
function _read_yaml_parameter_file() {
    declare -r filename="$1"
    local section='' multiline_mode=0

    # NB: cleanup any variables that may come from another run of this function
    unset "${!parameters@}"

    declare -ga parameter_names=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^([[:blank:]]*|^[[:blank:]]*---[[:blank:]]*)$  ]]; then
            continue
        fi

        # Replace tabs with spaces
        line="${line//$'\t'/  }"
        # Remove comments
        line="${line%%#*}"
        # Remove trailing whitespace
        line="${line%"${line##*[![:space:]]}"}"

        if [ -z "$section" ];then
            # Top level
            if [[ "${line%:}" != "parameters" ]]; then
                LOG_FATAL "Top level item must be 'parameters'"
            else
                section="${line%:}"
            fi
        else
            if [[ "$line" =~ ^([[:blank:]]+)([^[:blank:]:]+)[[:blank:]]*:[[:blank:]]*(.*) ]]; then
                if [ "$multiline_mode" -eq 1 ]; then
                    attributes["$attribute_name"]="${attribute_value%%"$value_sep"}"
                    multiline_mode=0
                    unset value_sep attribute_name attribute_value
                fi
                left="${BASH_REMATCH[2]}"
                right="${BASH_REMATCH[3]}"
            elif [[ "$multiline_mode" -eq 1 && "$line" =~ ^([[:blank:]]+)(.*) ]]; then
                attribute_value="$attribute_value${BASH_REMATCH[2]}$value_sep"
            fi

            if [ "$multiline_mode" -eq 0 ]; then
                if [ -z "$right" ]; then
                    # Nothing after ':'
                    param_arg_name="$left"
                    param_var_name="${left//-/_}"
                    declare -gA "parameters_${param_var_name}"
                    declare +n attributes
                    declare -n attributes="parameters_${param_var_name}"
                    parameter_names+=("$param_var_name")
                    attributes["var_name"]="$param_var_name"
                    attributes["long_option"]="$param_arg_name"
                elif [[ "$right" =~ ([\>\|])-? ]]; then
                    multiline_mode=1
                    if [[ "${BASH_REMATCH[1]}" == ">" ]]; then
                        value_sep=' '
                    else
                        value_sep='\n'
                    fi
                    attribute_name="$left"
                    attribute_value=''
                else
                    if [[ "${right,,}" =~ ^yes|true$ ]]; then
                        right=1
                    elif [[ "${right,,}" =~ ^no|false$ ]]; then
                        right=0
                    elif [[ "$right" =~ ^[[:digit:]]+$ ]]; then
                        :
                    elif [[ "$right" =~ ^([\'\"])(.*)([\'\"])$ ]]; then
                        right="${BASH_REMATCH[2]}"
                    fi

                    # shellcheck disable=SC2034
                    attributes["$left"]="$right"
                fi
            fi
        fi
    done < "$filename"
}

function parse_yaml_parameter_file() {
    declare -ga parameter_names
    declare -gr GREP
    declare -r filename="$1"
    LOG_INFO "Reading YAML file: $filename"
    _read_yaml_parameter_file "$filename"

    declare -gA parameter_short_to_long=()

    # shellcheck disable=SC2154
    for param_name in "${parameter_names[@]}"; do
        declare -n parameter_attributes="parameters_${param_name}"

        if [ -z "${parameter_attributes[type]}" ]; then
            LOG_FATAL "Missing 'type' attribute for $param_name"
        fi
        if [[ "${parameter_attributes[type]}" == bool && -n "${parameter_attributes[default]}" ]]; then
            LOG_FATAL "Bool parameter '$param_name' cannot have a default value!"
        fi

        if [ -n "${parameter_attributes[short_option]}" ]; then
            # shellcheck disable=SC2034
            parameter_short_to_long["${parameter_attributes[short_option]}"]="${parameter_attributes[long_option]}"
        fi

        LOG_DEBUG "Attributes for $param_name: $(variable_to_string "parameters_${param_name}")"
    done
}
