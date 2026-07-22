#!/bin/bash
#
# Test suite for userconf shell configuration.
# Run from anywhere: ./tests/run_tests.sh
#
# Each tests/test_*.sh file defines test_* functions; this runner sources them
# all into one shell (so the pass/fail counters aggregate) and calls each.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Be hermetic: git hooks export GIT_DIR/GIT_INDEX_FILE, which would make every
# directory look like a git repo to the tests.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX

# shellcheck source=tests/lib.sh
source "$SCRIPT_DIR/lib.sh"

defined_tests() {
    declare -F | awk '$3 ~ /^test_/ {print $3}' | sort
}

echo "========================================"
echo "Running userconf test suite"
echo "========================================"
echo ""

for suite in "$SCRIPT_DIR"/test_*.sh; do
    before=$(defined_tests)
    # shellcheck source=/dev/null
    source "$suite"
    for testcase in $(comm -13 <(echo "$before") <(defined_tests)); do
        "$testcase"
        echo ""
    done
done

echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Total:  $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "========================================"

[ "$TESTS_FAILED" -eq 0 ]
