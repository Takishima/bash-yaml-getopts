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
TEST_DIR="$BASEPATH"
SCRIPT_DIR=$(realpath "$BASEPATH/../scripts")

# ==============================================================================

if ! command -v shunit2 > /dev/null 2>&1; then
    echo 'Unable to locate shunit2 to execute tests!' >&2
    exit 1
fi
SHUNIT2="$(command -v shunit2)"

# ==============================================================================

# shellcheck source=../scripts/config.bash
. "$SCRIPT_DIR/parse_yaml.bash"

set +o errexit

# ==============================================================================

test_read_yaml_parameter_file() {
    _read_yaml_parameter_file "$TEST_DIR/test.yaml"
    ${_ASSERT_EQUALS_} "'exit code'" 0 "'$?'"

    var="$(variable_to_string parameters_names)"
    assertEquals 'Test parameters_names' 'parameters_names=([0]="build" [1]="compile_db" [2]="start" [3]="name")' "$var"

    assertNotNull "parameters_build[...]" "${parameters_build[*]}"
    assertEquals 'build[help]' 'Build directory' "${parameters_build[help]}"
    assertEquals 'build[type]' 'path' "${parameters_build[type]}"
    assertEquals 'build[short_option]' 'B' "${parameters_build[short_option]}"
    assertEquals 'build[default]' 'build' "${parameters_build[default]}"

    assertNotNull "parameters_start[...]" "${parameters_start[*]}"
    assertEquals 'start[help]' 'Start value for counter' "${parameters_start[help]}"
    assertEquals 'start[type]' 'int' "${parameters_start[type]}"
    assertEquals 'start[short_option]' 's' "${parameters_start[short_option]}"
    assertNull 'start[default] is null' "${parameters_start[default]}"

    assertNotNull "parameters_compile_db[...]" "${parameters_compile_db[*]}"
    assertEquals 'compile_db[help]' 'Generate compile database' "${parameters_compile_db[help]}"
    assertEquals 'compile_db[type]' 'bool' "${parameters_compile_db[type]}"
    assertNull 'compile_db[short_option] is null' "${parameters_compile_db[short_option]}"
    assertNull 'compile_db[default] is null' "${parameters_compile_db[default]}"

    assertNotNull "parameters_name[...]" "${parameters_name[*]}"
    assertEquals 'name[help]' 'Name' "${parameters_name[help]}"
    assertEquals 'name[type]' 'string' "${parameters_name[type]}"
    assertNull 'name[short_option] is null' "${parameters_name[short_option]}"
    assertNull 'name[default] is null' "${parameters_name[default]}"
}


test_read_yaml_parameter_file_multiline() {
    _read_yaml_parameter_file "$TEST_DIR/multiline_string.yaml"
    ${_ASSERT_EQUALS_} "'exit code'" 0 "'$?'"

    assertNotNull "parameters_build[...]" "${parameters_build[*]}"
    assertEquals 'build[help]' 'Directory\nDefault value: build' "${parameters_build[help]}"
    assertEquals 'build[type]' 'path' "${parameters_build[type]}"
    assertEquals 'build[short_option]' 'B' "${parameters_build[short_option]}"
    assertEquals 'build[default]' 'build' "${parameters_build[default]}"

    assertNotNull "parameters_compile_db[...]" "${parameters_compile_db[*]}"
    assertEquals 'compile_db[help]' 'Generate compile database' "${parameters_compile_db[help]}"
    assertEquals 'compile_db[type]' 'bool' "${parameters_compile_db[type]}"
    assertNull 'compile_db[short_option] is null' "${parameters_compile_db[short_option]}"
    assertNull 'compile_db[default] is null' "${parameters_compile_db[default]}"
}

# ==============================================================================

test_parse_yaml_parameter_file() {
     parse_yaml_parameter_file "$TEST_DIR/test.yaml"
    ${_ASSERT_EQUALS_} "'exit code'" 0 "'$?'"

    var="$(variable_to_string parameters_names)"
    assertEquals 'Test parameters_names' 'parameters_names=([0]="build" [1]="compile_db" [2]="start" [3]="name")' "$var"

    var="$(variable_to_string parameters_short_to_long)"
    assertEquals 'short_to_long' 'parameters_short_to_long=([B]="build" [s]="start" )' "$var"

    assertEquals 'build[help]' 'Build directory' "${parameters_build[help]}"
    assertEquals 'build[short_option]' 'B' "${parameters_build[short_option]}"
    assertEquals 'start[help]' 'Start value for counter' "${parameters_start[help]}"
    assertEquals 'start[short_option]' 's' "${parameters_start[short_option]}"
    assertEquals 'compile_db[help]' 'Generate compile database' "${parameters_compile_db[help]}"
    assertNull 'compile_db[short_option] is null' "${parameters_compile_db[short_option]}"
    assertEquals 'name[help]' 'Name' "${parameters_name[help]}"
    assertNull 'name[short_option] is null' "${parameters_name[short_option]}"
}

test_parse_yaml_parameter_file_invalid() {
    stderr=$(parse_yaml_parameter_file "$TEST_DIR/invalid_type.yaml" 2>&1)
    ${_ASSERT_NOT_EQUALS_} "'exit code'" 0 "$?"
    assertContains "$stderr" "Missing 'type' attribute for"

    stderr=$(parse_yaml_parameter_file "$TEST_DIR/invalid_bool.yaml" 2>&1);
    ${_ASSERT_NOT_EQUALS_} "'exit code'" 0 "$?"
    assertContains "$stderr" "Bool parameter"
    assertContains "$stderr" "cannot have a default value"
}

# ==============================================================================

# shellcheck disable=SC1090
. "$SHUNIT2"
