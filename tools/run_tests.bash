#! /bin/bash

BASEPATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TEST_DIR="$(realpath "$BASEPATH/../test")"

# ==============================================================================

failed=0

cd "$TEST_DIR" || exit
for test_file in *_test.bash; do
    echo '----------------------------------------'
    echo -e "Running tests from $test_file\n"
    bash "$test_file" || failed=1
    echo '========================================'
done

exit "$failed"

# ==============================================================================
