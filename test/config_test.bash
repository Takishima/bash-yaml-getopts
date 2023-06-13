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

foo() {
   :
}
goo() {
    :
}

test_locate_cmd() {
    ${_ASSERT_NULL_} "'MYSHELL null'" "'$MYSHELL'"
    locate_cmd MYSHELL "$SHELL"
    ${_ASSERT_NOT_NULL_} "'MYSHELL not null'" "'$MYSHELL'"
    ${_ASSERT_EQUALS_} "'$SHELL'" "'$MYSHELL'"

    ${_ASSERT_NULL_} "'FUNC null'" "'$FUNC'"
    locate_cmd FUNC hoo foo goo
    ${_ASSERT_NOT_NULL_} "'FUNC not null'" "'$FUNC'"
    ${_ASSERT_EQUALS_} "'foo'" "'$FUNC'"
}

# ==============================================================================

test_verify_system() {
    declare -g PARAM_YAML_CONFIG="$BASEPATH/test.yaml"
    verify_system

    PARAM_YAML_CONFIG=''
    stderr="$(verify_system 2>&1)"
    stdout="$(verify_system 2> /dev/null)"
    ${_ASSERT_EQUALS_} "'exit code'" 1 "'$?'"
    ${_ASSERT_NULL_} "'Has no stdout output'" "'$stdout'"
    ${_ASSERT_NOT_NULL_} "'Has stderr output'" "'$stderr'"
    assertContains "$stderr" "Variable 'PARAM_YAML_CONFIG'"

    # shellcheck disable=SC2034
    PARAM_YAML_CONFIG='test'
    stderr="$(verify_system 2>&1)"
    ${_ASSERT_EQUALS_} "'exit code'" 1 "'$?'"
    ${_ASSERT_NOT_NULL_} "'Has stderr output'" "'$stderr'"
    assertContains "$stderr" "YAML config file"
    assertContains "$stderr" "not readable"
}

# ==============================================================================

test_variable_to_string() {
    # shellcheck disable=SC2034
    declare -a a=(1 2 3 4)
    # shellcheck disable=SC2034
    declare -a aa=(10 20 30 40)
    string="$(variable_to_string a)"
    ${_ASSERT_EQUALS_} "'a=([0]=\"1\" [1]=\"2\" [2]=\"3\" [3]=\"4\")'" "'$string'"
    string="$(variable_to_string aa)"
    ${_ASSERT_EQUALS_} "'aa=([0]=\"10\" [1]=\"20\" [2]=\"30\" [3]=\"40\")'" "'$string'"
}

# ==============================================================================

# shellcheck disable=SC1090
. "$SHUNIT2"
