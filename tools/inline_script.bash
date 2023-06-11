#!/usr/bin/env bash
# MIT License
#
# Copyright (c) 2022-2022 Carlo Corradini
# Copyright (c) 2023 Damien Nguyen
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

# Inspired by https://gist.github.com/joehillen/30f08738c1c3c0ca3e4c754ad33ad2ff

# Disable wildcard character expansion
set -o noglob

# PID shell
SELF_PID=$$

BASEPATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}" )" &> /dev/null && pwd )

. "$BASEPATH/../scripts/config.bash"

# ==============================================================================

show_help() {
    local default_log_level="${_FROM_LOG_LEVEL[$LOG_LEVEL]:-$LOG_LEVEL_INFO}"
    cat << EOF
Usage: $(basename "$0") --in-file <FILE> [--disable-color] [--help] [--log-level <LEVEL>] [--out-file <FILE>] [--overwrite]

reCluster bundle script.

Options:
  --disable-color      Disable color

  --help               Show this help message and exit

  --in-file <FILE>     Input file
                       Values:
                         Any valid file

  --log-level <LEVEL>  Logger level
                       Default: ${default_log_level,,}
                       Values:
                         fatal    Fatal level
                         warn     Warning level
                         info     Informational level
                         debug    Debug level
                         silent   Silent level (ie. disable output)

  --out-file <FILE>    Output file
                       Default: [IN_FILE_NAME].inlined[IN_FILE_EXTENSION]
                       Values:
                         Any valid file

  --overwrite          Overwrite input file

  --var <name=value>   Define a bash variable when processing source statements
EOF
}

# Cache
CACHE=

# cache_add <path>
cache_add() {
    if [ -z "$CACHE" ]; then
        CACHE=$(printf '%s\n' "$1")
    else
        CACHE=$(printf '%s\n%s\n' "$CACHE" "$1")
    fi
}

# cache_has <path>
cache_has() {
    while read -r _entry; do
        if [ "$_entry" = "$1" ]; then
            return 0
        fi
    done << EOF
$CACHE
EOF

    return 1
}

# Inline sources ('source' or '.') of given script file
# inline_sources <file>
inline_sources() { # shellcheck disable=SC2094
    declare -rg SED GREP
    declare -r _file="$1" _file_safe="$1"
    declare -r _regex='^([[:space:]]*)(source|\.)[[:space:]]+(.+)'
    declare -r _regex_inline_skip='^[[:space:]]*#[[:space:]]*inline[[:space:]]+skip.*'
    declare -r _regex_shellcheck='^[[:space:]]*#[[:space:]]*shellcheck[[:space:]]+source=(.+)'
    declare -r _include_guard_regex='^\[ "\$\{_sourced_[a-z_]+\}" != "" \].*'
    # shellcheck disable=SC2016
    declare -r _source_protection_macro='[ "${BASH_SOURCE[0]}" -ef "$0" ]'
    local _inline_skip=false _expanded_vars='' _source_file_shellcheck='' _file_dir=''

    _file_dir="$(dirname "$_file")"

    [ -f "$_file" ] || LOG_FATAL "File '$_file' does not exists"
    LOG_INFO "Reading file '$_file'"

    # Add to cache
    cache_add "$_file"

    # Read
    while IFS='' read -r _line; do
        LOG_DEBUG "Analyzing line '$_line'"

        if printf "%s\n" "$_line" | "$GREP" -q -E "$_regex_inline_skip"; then
            # # inline skip
            _inline_skip=true
            LOG_DEBUG "Inline skip '$_line'"

            # Print line
            printf '%s\n' "$_line"
        elif [[ "${_line:0:32}" == "$_source_protection_macro" ]]; then
            # [ "${BASH_SOURCE[0]}" -ef "$0" ] && ...
            LOG_DEBUG "Skip source protection macro"
        elif [[ "$_line" =~ $_include_guard_regex ]]; then
            # [ "${_sourced_XXX}" != "" ] && ...
            LOG_DEBUG "Skip Bash include guard"
        elif printf "%s\n" "$_line" | "$GREP" -q -E "$_regex_shellcheck"; then
            # # shellcheck source=...
            LOG_DEBUG "ShellCheck source '$_line'"

            # Source
            _source_file_shellcheck=$(printf "%s\n" "$_line" | "$SED" -n -r "s/$_regex_shellcheck/\1/p")
            # Print line
            printf '%s\n' "$_line"
        elif printf "%s\n" "$_line" | "$GREP" -q -E "$_regex"; then
            # source ...
            # . ...
            LOG_DEBUG "Source '$_line'"

            # Source
            _source_file=$(printf "%s\n" "$_line" | "$SED" -n -r "s/$_regex/\3/p" | "$SED" -e 's/^"//' -e 's/"$//')

            # Check skip
            [ "$_inline_skip" = false ] || {
                # Skip
                LOG_WARN "Skipping source '$_line'"
                # Reset inline skip
                _inline_skip=false
                # Reset shellcheck
                _source_file_shellcheck=
                # Print line
                printf '%s\n' "$_line"
                continue
            }

            # Resolve source path
            _path=
            if printf "%s\n" "$_source_file" | $GREP -q -E -v '.*/.*'; then
                # Search $PATH
                LOG_DEBUG "Searching '\$PATH'"

                _path=$(command -v "$_source_file" || :)
            fi
            if [ -z "$_path" ]; then
                # Resolve links, relative paths, ~, quotes, and escapes
                LOG_DEBUG "Path is undefined, continue searching"

                _path=$_source_file
                if printf "%s\n" "$_path" | "$GREP" -q -E -v '^/|^\$'; then
                    # Path does not start with '/' or '$' symbol, prepend directory
                    _path="$_file_dir/$_path"
                fi

                if [[ "$_path" =~ ^\$BASEPATH/(.*) ]]; then
                    # Path starts with $BASEPATH, assume that BASEPATH is parent script dir
                    LOG_DEBUG "Assume \$BASEPATH = $_file_dir"
                    _expanded_var="\$BASEPATH=$_file_dir"
                    _path="$_file_dir/${BASH_REMATCH[1]}"
                fi

                if [[ "$_path" =~ ^\$([^\/]+)/(.*) ]] && [ -n "${!BASH_REMATCH[1]}" ]; then
                    # Path starts with a bash variable, replace variable name if is defined
                    if [ ! -d "${!BASH_REMATCH[1]}" ]; then
                        LOG_DEBUG "${!BASH_REMATCH[1]} does not exist! skipping"
                    else
                        LOG_DEBUG "Resolved \$${BASH_REMATCH[1]} = ${!BASH_REMATCH[1]}"
                        _expanded_var="${BASH_REMATCH[1]}=${!BASH_REMATCH[1]}"
                        _path="${!BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
                    fi
                fi

                # Canonicalize
                _path=$(eval readlink -f "$_path" || :)
                LOG_DEBUG "Path candidate '$_path'"

                if [ ! -f "$_path" ] && [ -n "$_source_file_shellcheck" ]; then
                    # File does not exists, try shellcheck
                    LOG_DEBUG "Path '$_path' is invalid, searching ShellCheck"

                    _path=$_source_file_shellcheck
                    if printf "%s\n" "$_path" | "$GREP" -q -E -v '^/'; then
                        # Path does not start with '/' symbol, prepend directory
                        _path="$_file_dir/$_path"
                    fi

                    # Canonicalize
                    _path=$(readlink -f "$_path" || :)
                    LOG_DEBUG "Path candidate '$_path'"
                    # Reset shellcheck
                    _source_file_shellcheck=
                fi
            fi

            # Check path
            [ -f "$_path" ] || LOG_FATAL "Unable to resolve source file path '$_source_file'"
            LOG_DEBUG "Source '$_source_file' resolved to '$_path'"

            # Comment source
            printf '# %s\n' "$_line"
            if [ -n "$_expanded_var" ]; then
                var_name=$(echo "$_expanded_var" | cut -d= -f1)
                var_value=$(echo "$_expanded_var" | cut -d= -f2)
                var_value=$(realpath --relative-to="$_file_dir" "$var_value")
                # shellcheck disable=SC2094
                printf '# %s="%s" (relative to %s)\n' "$var_name" "$var_value" "$(basename "$_file")"
            fi


            # Check if already sourced
            ! cache_has "$_path" || {
                LOG_WARN "Recursion detected, source '$_source_file' of '$_file'"
                kill "$SELF_PID"
                wait "$SELF_PID"
            }

            # Inline source and remove shebang
            inline_sources "$_path" | "$SED" '/^#!.*/d'
        else
            # Reset inline skip
            _inline_skip=false
            # Reset shellcheck
            _source_file_shellcheck=
            # Print line
            printf '%s\n' "$_line"
        fi
    done < "$_file_safe"  # should be $_file but shellcheck complains with SC2094...
}




# parse_args <arg_1> ... <arg_N>
parse_args() {
    # Assert argument has a value
    # parse_args_assert_value <name> <value> [<args>...]
    parse_args_assert_value() {
        [ -n "$2" ] || LOG_FATAL "Argument '$1' requires a non-empty value"
    }

    while [ $# -gt 0 ]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            --in-file)
                parse_args_assert_value "$@"

                IN_FILE=$2
                shift 2
                ;;
            --log-level)
                parse_args_assert_value "$@"

                _level="${_LOG_LEVELS[${2^^}]}"
                [ -n "$_level" ] || LOG_FATAL "Value '$2' of argument '$1' is invalid" && LOG_LEVEL="$_level"
                shift 2
                ;;
            --out-file)
                parse_args_assert_value "$@"

                OUT_FILE=$2
                shift 2
                ;;
            --var)
                parse_args_assert_value "$@"
                LOG_DEBUG "Setting and exporting $2"
                eval "export '$2'"
                shift 2
                ;;
            -*)
                LOG_WARN "Unknown argument '$1' is ignored"
                shift
                ;;
            *)
                LOG_WARN "Skipping argument '$1'"
                shift
                ;;
        esac
    done

    # Determine output file
    if [ -n "$IN_FILE" ] && [ -z "$OUT_FILE" ]; then
        LOG_FATAL 'Missing output file! Did you specify --out-file ?'
    fi
}

# verify_system
verify_system() {
    declare -g GREP SED
    locate_cmd GREP grep
    locate_cmd SED gsed sed

    [ -n "$IN_FILE" ] || LOG_FATAL "Input file required"
    [ -f "$IN_FILE" ] || LOG_FATAL "Input file '$IN_FILE' does not exists"
    [ -n "$OUT_FILE" ] || LOG_FATAL "Output file required"
    [ ! -f "$OUT_FILE" ] || LOG_FATAL "Output file '$OUT_FILE' already exists"
    [ "${BASH_VERSINFO[0]}" -ge 4 ] || echo "Associative arrays require Bash>=4.x (you have: $BASH_VERSION)"
}

# Inline input file
# inline
inline() {
    LOG_INFO "Inlining file '$IN_FILE'"
    _inlined=$(inline_sources "$(readlink -f "$IN_FILE")") || LOG_FATAL "Error inlining file '$IN_FILE'"

    LOG_INFO "Saving file '$OUT_FILE'"
    printf '%s\n' "$_inlined" > "$OUT_FILE"
}

# ==============================================================================

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    parse_args "$@"
    verify_system
    inline
fi
