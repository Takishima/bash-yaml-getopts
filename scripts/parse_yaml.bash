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
    [ -n "$AWK" ] || LOG_FATAL_INTERNAL "'AWK' variable not defined!"

    declare -r filename="$1"
    declare -a awk_args=(-F: -vidx=0)
    local eval_str

    # NB: cleanup any variables that may come from another run of this function
    unset "${!parameters@}"

    # shellcheck disable=SC2016
    eval_str=$($AWK "${awk_args[@]}" '{
          gsub(/^[ \t]+|[ \t]+$/, "", $1);
          gsub(/^[ \t]+|[ \t]+$/, "", $2);
          gsub(/[ \t]*#.*$/, "", $1);
          gsub(/[ \t]*#.*$/, "", $2);

          if ($1 !~ /^[ \t]*$/ && $1 !~ /^---[ \t]*$/) {
              if (section == "") {
                  # Top level
                  if ($1 != "parameters") {
                      print "Top level item must be '\''parameters'\''" > "/dev/stderr";
                      exit 1;
                  }
                  else {
                      section=$1;
                  }
              }
              else {
                  # Either variable name or variable settings
                  # NB: we rely on the fact that a variable name has an empty second field
                  if ($2 == "") {
                      param_arg_name=$1;
                      param_var_name=$1;
                      gsub(/-/, "_", param_var_name);
                      parameters[param_var_name,"var_name"]=param_var_name;
                      parameters[param_var_name,"long_option"]=param_arg_name;
                      parameter_names[idx++]=param_var_name;
                  }
                  else {
                      param_attribute=$1;
                      gsub(/['\'']/, "\"", $2);

                      if (tolower($2) ~ /^yes|true|no|false$/) {
                          if (tolower($2) ~ /^yes|true/) {
                              param_value=1;
                          }
                          else {
                              param_value=0;
                          }
                      }
                      else if ($2 ~ /^[0-9]+$/) {
                          param_value=$2;
                      }
                      else {
                          param_value="'\''"$2"'\''";
                      }

                      if (parameters[param_var_name,param_attribute] == "") {
                          parameters[param_var_name,param_attribute]=param_value;
                      }
                      else {
                          print "Attribute " param_attribute " for " param_arg_name " already set!"> "/dev/stderr";
                          exit 1;
                      }
                  }
              }
          }
     }
     END {
         print "declare -ga parameter_names=()";
         for(idx in parameter_names) {
             param_name = parameter_names[idx];
             print "parameter_names+=(" param_name ")";
             print "declare -gA parameters_" param_name "=()";
         }
         for (combined in parameters) {
             split(combined, separate, SUBSEP);
             param_var_name=separate[1];
             param_attribute=separate[2];
             print "parameters_" param_var_name "[\""param_attribute"\"]="parameters[param_var_name,param_attribute]";";
         }
    }' "${filename}")
     # echo "$eval_str"
     eval "$eval_str"
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
            parameter_attributes[short_option]=${parameter_attributes[short_option]//\"/}
            # shellcheck disable=SC2034
            parameter_short_to_long["${parameter_attributes[short_option]}"]="${parameter_attributes[long_option]}"
        fi
        if [ -n "${parameter_attributes[help]}" ]; then
            parameter_attributes[help]=${parameter_attributes[help]//\"/}
        fi

        LOG_DEBUG "Attributes for $param_name: $(variable_to_string "parameters_${param_name}")"
    done
}
