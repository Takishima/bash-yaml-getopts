#! /bin/bash
# shellcheck disable=SC2154
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

BASEPATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SCRIPT_DIR=$(realpath "$BASEPATH/../scripts")


# ==============================================================================

if ! command -v shunit2 > /dev/null 2>&1; then
    echo 'Unable to locate shunit2 to execute tests!' >&2
    exit 1
fi
SHUNIT2="$(command -v shunit2)"

# ==============================================================================

# shellcheck source=../scripts/config.bash
. "$SCRIPT_DIR/config.bash"

set +o errexit

# ==============================================================================

run() {
    setup_script="$1"
    shift
    LOG_LEVEL=WARN "$BASEPATH/run.bash" "$setup_script" "$BASEPATH/test.yaml" "$@"
}

# ==============================================================================

test_bool_param() {
    for setup_script in "$SCRIPT_DIR"/setup*; do
        echo "Testing for setup script: $setup_script"
        IFS=" " read -r -a result <<< "$(run "$setup_script" -- compile_db _compile_db_was_set)"
        ${_ASSERT_NULL_} "'no args'" "'${result[*]}'"

        IFS=" " read -r -a result <<< "$(run "$setup_script" --compile-db -- compile_db _compile_db_was_set)"
        ${_ASSERT_EQUALS_} '1' "'${result[0]}'"
        ${_ASSERT_EQUALS_}  "'was set variable'" '1' "'${result[1]}'"

        IFS=" " read -r -a result <<< "$(run "$setup_script" --no-compile-db -- compile_db _compile_db_was_set)"
        ${_ASSERT_EQUALS_} '0' "'${result[0]}'"
        ${_ASSERT_EQUALS_} "'was set variable'" '1' "'${result[1]}'"
    done
}

# ==============================================================================

test_string_param() {
    for setup_script in "$SCRIPT_DIR"/setup*; do
        echo "Testing for setup script: $setup_script"
        run "$setup_script" -- name _name_was_set
        IFS=" " read -r -a result <<< "$(run "$setup_script" -- name _name_was_set)"
        ${_ASSERT_NULL_} "'no args'" "'${result[*]}'"

        IFS=" " read -r -a result <<< "$(run "$setup_script" --name=aaa -- name _name_was_set)"
        ${_ASSERT_EQUALS_} 'aaa' "'${result[0]}'"
        ${_ASSERT_EQUALS_}  "'was set variable'" '1' "'${result[1]}'"
    done
}

# ==============================================================================

test_int_param() {
    for setup_script in "$SCRIPT_DIR"/setup*; do
        echo "Testing for setup script: $setup_script"
        run "$setup_script" -- start _start_was_set
        IFS=" " read -r -a result <<< "$(run "$setup_script" -- start _start_was_set)"
        ${_ASSERT_NULL_} "'no args'" "'${result[*]}'"

        IFS=" " read -r -a result <<< "$(run "$setup_script" --start=10 -- start _start_was_set)"
        ${_ASSERT_EQUALS_} '10' "'${result[0]}'"
        ${_ASSERT_EQUALS_}  "'was set variable'" '1' "'${result[1]}'"
    done
}

# ==============================================================================

test_path_param() {
    for setup_script in "$SCRIPT_DIR"/setup*; do
        echo "Testing for setup script: $setup_script"
        run "$setup_script" -- build _build_was_set
        IFS=" " read -r -a result <<< "$(run "$setup_script" -- build _build_was_set)"
        ${_ASSERT_EQUALS_} "'build'" "'${result[0]}'"
        ${_ASSERT_EQUALS_}  "'was set variable'" '1' "'${result[1]}'"

        IFS=" " read -r -a result <<< "$(run "$setup_script" --build="$PWD" -- build _build_was_set)"
        ${_ASSERT_EQUALS_} "'$PWD'" "'${result[0]}'"
        ${_ASSERT_EQUALS_}  "'was set variable'" '1' "'${result[1]}'"
    done
}

# ==============================================================================

# shellcheck disable=SC1090
. "$SHUNIT2"
