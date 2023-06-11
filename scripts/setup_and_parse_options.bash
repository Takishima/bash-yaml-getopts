#! /bin/bash

# ==============================================================================

[ "${_sourced_setup_options}" != "" ] && return || _sourced_setup_options=.
[ "${BASH_SOURCE[0]}" -ef "$0" ] && echo "$0 should not be executed, only sourced" >&2 && exit 1

BASEPATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}" )" &> /dev/null && pwd )

# ==============================================================================

. "$BASEPATH/parse_yaml.bash"
. "$BASEPATH/parse_options.bash"

# ------------------------------------------------------------------------------

PARAM_YAML_CONFIG="$(realpath "$PARAM_YAML_CONFIG")"

verify_system
parse_yaml_parameter_file "$PARAM_YAML_CONFIG"
parse_args "$@"
shift $((OPTIND-1)) # remove parsed options and args from $@ list

# ==============================================================================
