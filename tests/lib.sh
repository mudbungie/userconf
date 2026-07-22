#!/bin/bash
#
# Shared test harness: counters, assertions, per-test sandbox.
# Sourced by tests/run_tests.sh; never run directly.
#

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${GREEN}PASS${NC}: $1"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${RED}FAIL${NC}: $1"
    if [ -n "$2" ]; then
        echo "       Expected: $2"
    fi
    if [ -n "$3" ]; then
        echo "       Got: $3"
    fi
}

skip() {
    echo -e "${YELLOW}SKIP${NC}: $1 - $2"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$message"
    else
        fail "$message" "$expected" "$actual"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"
    if echo "$haystack" | grep -q "$needle"; then
        pass "$message"
    else
        fail "$message" "string containing '$needle'" "$haystack"
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"
    if ! echo "$haystack" | grep -q "$needle"; then
        pass "$message"
    else
        fail "$message" "string NOT containing '$needle'" "$haystack"
    fi
}

assert_true() {
    local result="$1"
    local message="$2"
    if [ "$result" -eq 0 ]; then
        pass "$message"
    else
        fail "$message" "exit code 0" "exit code $result"
    fi
}

assert_false() {
    local result="$1"
    local message="$2"
    if [ "$result" -ne 0 ]; then
        pass "$message"
    else
        fail "$message" "non-zero exit code" "exit code $result"
    fi
}

# Fresh temp dir per test, with the shared shell functions loaded.
setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR" || return 1
    source "$REPO_ROOT/shell_config/00_functions.sh"
}

teardown() {
    cd "$REPO_ROOT" || return 1
    rm -rf "$TEST_DIR"
}

# Load deploy.sh's function definitions without executing its main logic.
source_deploy_functions() {
    source <(sed -n '1,/^if \[\[/p' "$REPO_ROOT/deploy.sh" | head -n -1)
}
