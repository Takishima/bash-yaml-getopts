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
    declare -g parameter_names

    parameter_names=('help' 'log_level' "${parameter_names[@]}")

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
