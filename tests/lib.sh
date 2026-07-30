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

# --- A sandbox machine for the commit-invariant suites -------------------
#
# Its own HOME, its own global gitconfig pointing at githooks-global, and the
# environment scrubbed of everything the real machine exports - so no case can
# pass by accident of the developer's own setup. Shared by test_git_*.sh.

SANDBOX_EMAIL="sandbox@example.invalid"

# A machine with one identity and this repo as its global hooks dir, plus a
# repo on it holding one commit. Leaves the shell inside that repo.
_sandbox_machine() {
    _ENFORCE_PRIOR_HOME=$HOME
    _ENFORCE_PRIOR_TMPDIR=${TMPDIR-}
    export HOME="$TEST_DIR/home"

    # setup() puts TEST_DIR under the temp dir, which is precisely what the
    # throwaway exemption skips - so aim TMPDIR at a sibling. The repo below
    # then sits outside it and is enforced, as one in ~/dev would be.
    export TMPDIR="$TEST_DIR/tmpdir"
    mkdir -p "$TMPDIR"
    mkdir -p "$HOME"
    unset XDG_CONFIG_HOME GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
    unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

    printf '[user]\n\tname = Sandbox\n\temail = %s\n[core]\n\thooksPath = %s\n' \
        "$SANDBOX_EMAIL" "$REPO_ROOT/githooks-global" > "$HOME/.gitconfig"

    mkdir -p "$TEST_DIR/repo"
    cd "$TEST_DIR/repo" || return 1
    git init -q
    echo seed > seed.txt
    git add seed.txt
    git commit -qm "seed"
}

_leave_sandbox() {
    export HOME="$_ENFORCE_PRIOR_HOME"
    if [ -n "$_ENFORCE_PRIOR_TMPDIR" ]; then
        export TMPDIR="$_ENFORCE_PRIOR_TMPDIR"
    else
        unset TMPDIR
    fi
    teardown
}
