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
# directory look like a git repo to the tests. The identity pair goes with
# them, and for the same reason - git exports it to every hook, and the shell
# exports it to every shell (see README, "Identity is enforced"), so a sandbox
# commit would be authored by the real machine rather than by its own config.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
# balls' safegit exports config redirects to its subprocesses (GIT_CONFIG_GLOBAL
# =/dev/null and friends); a delivery-gate run would then sandbox-commit with no
# identity and die. Same hermeticity rule as the vars above.
unset GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_CONFIG_NOSYSTEM GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS

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
