[ "${_sourced_parse_options}" != "" ] && return || _sourced_parse_options=.

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

function no_arg() {
    [ -z "$OPTARG" ] || LOG_FATAL "No arg allowed for --$OPT option"
}

function needs_arg() {
    [ -n "$OPTARG" ] || LOG_FATAL "Missing arg for -$OPT/--$OPT option"
    [ "$flag_value" -ne 0 ] || LOG_FATAL "Cannot specify --no-$OPT for non-flag argument --$OPT"
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

function generate_getopts_args() {
    local getopts_args=''
    # shellcheck disable=SC2154
    for param_name in "${parameter_names[@]}"; do
        declare -n parameter_attributes="parameters_${param_name}"
        if [ -n "${parameter_attributes[short_option]}" ]; then
            getopts_args="${getopts_args}${parameter_attributes[short_option]}"
            if [[ "${parameter_attributes[type]}" != 'help'  && "${parameter_attributes[type]}" != 'bool' ]]; then
                getopts_args="${getopts_args}:"
            fi
        fi
    done > /dev/null 2> /dev/null
    echo "${getopts_args}-:"
}

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
    for param_name in "${parameter_names[@]}"; do
        # shellcheck disable=SC2178
        declare -n parameter_attributes="parameters_${param_name//-/_}"
        if [ -n "${parameter_attributes[short_option]}" ]; then
            help_lines_optnames+=("-${parameter_attributes[short_option]},--${parameter_attributes[long_option]}")
        else
            help_lines_optnames+=("--${parameter_attributes[long_option]}")
        fi
        if [ "$optnames_column_width" -lt "${#help_lines_optnames[-1]}" ]; then
            optnames_column_width="${#help_lines_optnames[-1]}"
        fi

        [ -n "${parameter_attributes[help]}" ] || LOG_FATAL "Missing description string for $param_name"
        readarray -t description_lines  <<<"${parameter_attributes[help]}"

        help_lines_description+=("${description_lines[0]}")
        if [[ -n "${parameter_attributes[default]}" && "${parameter_attributes[type]}" != 'bool' ]]; then
            help_lines_optnames+=('')
            help_lines_description+=("Default value: ${parameter_attributes[default]}")
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

    while getopts "${getopts_args}" OPT; do
        # shellcheck disable=SC2214,SC2295
        if [ "$OPT" = "-" ]; then     # long option: reformulate OPT and OPTARG
            OPT="${OPTARG%%=*}"       # extract long option name
            OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
            OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
        fi
        LOG_DEBUG "Processing: $OPT $OPTARG"

        # Support specifying --no-XXX to negate a boolean parameter
        flag_value=1
        if [[ $OPT =~ ^no-([a-zA-Z0-9_-]+) ]]; then
            OPT="${BASH_REMATCH[1]}"
            flag_value=0
        fi

        if [ "$OPT" == '?' ]; then
            # bad short option (error reported via getopts)
            exit 2
        elif [ -n "${parameter_short_to_long[$OPT]}" ]; then
            declare -n parameter_attributes="parameters_${parameter_short_to_long[$OPT]}"
        else
            declare -n parameter_attributes="parameters_${OPT//-/_}"
        fi

        var_type="${parameter_attributes[type]:-delegated}"
        var_name="${parameter_attributes[var_name]:-dummy_var}"

        if [ "$var_type" != "delegated" ]; then
            if [[ "$var_type" != 'bool' && "$var_type" != 'help' ]]; then
                needs_arg
            else
                no_arg
            fi
        fi

        LOG_DEBUG "var_type=$var_type var_name=$var_name"

        case "$var_type" in
            help)           generate_help_message
                            exit 0
                            ;;
            bool)           set_var "$var_name" "$flag_value"
                            ;;
            int | string)   set_var "$var_name" "$OPTARG"
                            ;;

            path)           [ -e "$OPTARG" ] || LOG_FATAL "-$OPT/--$OPT requires a valid path! Passed: $OPTARG"
                            set_var "$var_name" "$OPTARG"
                            ;;
            delegated )     success=1
                            if [ "$has_extra_args" -eq 1 ]; then
                                LOG_DEBUG "calling parse_extra_args '$OPT' '$OPTARG' '$flag_value'"
                                parse_extra_args "$OPT" "$OPTARG" "$flag_value" && success=0 || success=$?
                            fi

                            if [ "$success" -ne 0 ]; then
                                [ "$flag_value" -eq 1 ] \
                                    || LOG_FATAL "No option found for -$OPT/--$OPT (received --no-$OPT on cmdline)" \
                                        && LOG_FATAL "Illegal option: -$OPT/--$OPT"
                            fi
                            ;;
            * )             LOG_FATAL "Unknown variable type: $var_type"
                            ;;
        esac
    done

    for param_name in "${parameter_names[@]}"; do
        declare -n parameter_attributes="parameters_${param_name}" var_was_set="_${param_name}_was_set"
        if [[ "${var_was_set:-0}" == "0" && -n "${parameter_attributes[default]}" ]]; then
            set_var "${parameter_attributes[var_name]}" "${parameter_attributes[default]}"
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
