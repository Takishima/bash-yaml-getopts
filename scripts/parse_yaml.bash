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

# parse_yaml_parameters_file <filename>
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
# For each parameter, this function will add the name to an array named `parameters_names` and the parameter attributes
# will be stored in an associative array named `parameters_<param_name>` (e.g. `parameters_build`)
function _read_yaml_parameter_file() {
    declare -r filename="$1"
    declare -a indents=()
    local section='' multiline_mode=0

    # NB: cleanup any variables that may come from another run of this function
    unset "${!parameters@}"

    declare -gA sections=()
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

        LOG_DEBUG "Parsing: '$line'"

        # NB: top sections must have 0 indent and no values
        if [[ "$line" =~ ^([^[:blank:]:]+)[[:blank:]]*:[[:blank:]]*$ ]]; then
            section="${BASH_REMATCH[1]}"
            sections["$section"]=1
            declare -ga "${section}_names"
            LOG_DEBUG "Top level section: $section"
        else
            # Not top section
            if [[ "$line" =~ ^([[:blank:]]+)([^[:blank:]:]+)[[:blank:]]*:[[:blank:]]*(.*) ]]; then
                if [ "$multiline_mode" -eq 1 ]; then
                    LOG_DEBUG "  -> detected end of multiline string on previous line"
                    attributes["$attribute_name"]="${attribute_value%%"$value_sep"}"
                    LOG_DEBUG "  -> setting attribute $attribute_name = ${attributes[$attribute_name]}"
                    multiline_mode=0
                    unset value_sep attribute_name attribute_value
                fi

                indent_width="${#BASH_REMATCH[1]}"
                left="${BASH_REMATCH[2]}"
                right="${BASH_REMATCH[3]}"

                # shellcheck disable=SC2076
                if [[ ! " ${indents[*]} " =~ " $indent_width " ]]; then
                    indents+=("$indent_width")
                fi
            elif [[ "$multiline_mode" -eq 1 && "$line" =~ ^([[:blank:]]+)(.*) ]]; then
                attribute_value="$attribute_value${BASH_REMATCH[2]}$value_sep"
            fi

            if [ "$multiline_mode" -eq 0 ]; then
                if [ "${#indents[@]}" -gt 2 ]; then
                    unset "indents[-1]"
                    LOG_WARN "Item is too deeply nested. Ignoring: $line"
                    continue
                fi

                if [ -z "$right" ]; then
                    # Nothing after ':'
                    if [[ "${indents[1]}" == "$indent_width" ]]; then
                        LOG_WARN "Item on indent level 2 (indent width=$indent_width) must have a value"
                        LOG_WARN "-> was ignored"
                        continue
                    fi
                    LOG_DEBUG "  -> got: $left (for section $section)"
                    param_arg_name="$left"
                    param_var_name="${left//-/_}"
                    declare -gA "${section}_${param_var_name}"
                    declare +n attributes
                    declare -n attributes="${section}_${param_var_name}"
                    declare -n names="${section}_names"
                    names+=("$param_var_name")
                    declare +n names

                    if [[ "$section" == "parameters" ]]; then
                        attributes["var_name"]="$param_var_name"
                        attributes["long_option"]="$param_arg_name"
                    fi
                elif [[ "$right" =~ ([\>\|])-? ]]; then
                    LOG_DEBUG "  -> detected start of multiline string"
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
                    LOG_DEBUG "  -> setting attribute $left = $right"
                fi
            fi
            left=
            right=
        fi
    done < "$filename"
}

function parse_yaml_parameter_file() {
    declare -ga parameters_names
    declare -r filename="$1"
    LOG_INFO "Reading YAML file: $filename"
    _read_yaml_parameter_file "$filename"

    [ -z "${sections[parameters]}" ] && LOG_FATAL "Missing 'parameters' section in YAML file"

    declare -gA parameters_short_to_long=()

    # shellcheck disable=SC2154
    for param_name in "${parameters_names[@]}"; do
        declare -n parameters_attributes="parameters_${param_name}"

        if [ -z "${parameters_attributes[type]}" ]; then
            LOG_FATAL "Missing 'type' attribute for $param_name"
        fi
        if [[ "${parameters_attributes[type]}" == bool && -n "${parameters_attributes[default]}" ]]; then
            LOG_FATAL "Bool parameter '$param_name' cannot have a default value!"
        fi

        if [ -n "${parameters_attributes[short_option]}" ]; then
            # shellcheck disable=SC2034
            parameters_short_to_long["${parameters_attributes[short_option]}"]="${parameters_attributes[long_option]}"
        fi

        LOG_DEBUG "Attributes for $param_name: $(variable_to_string "parameters_${param_name}")"
    done
}
