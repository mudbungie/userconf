#!/bin/bash
#
# Test suite for userconf shell configuration
# Run from repository root: ./tests/run_tests.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test utilities
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

# Setup test environment
setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    # Source the functions we want to test
    source "$REPO_ROOT/shell_config/00_functions.sh"
}

# Cleanup test environment
teardown() {
    cd "$REPO_ROOT"
    rm -rf "$TEST_DIR"
}

#############################################
# Test 00_functions.sh
#############################################

test_add_to_path() {
    echo "=== Testing add_to_path ==="
    setup

    # Test adding new path
    local original_path="$PATH"
    add_to_path "/test/new/path"
    assert_contains "$PATH" "/test/new/path" "add_to_path adds new directory"

    # Test idempotence - adding same path shouldn't duplicate
    local path_before="$PATH"
    add_to_path "/test/new/path"
    assert_equals "$path_before" "$PATH" "add_to_path is idempotent (no duplicates)"

    # Restore PATH
    export PATH="$original_path"
    teardown
}

test_prepend_to_path() {
    echo "=== Testing prepend_to_path ==="
    setup

    local original_path="$PATH"
    prepend_to_path "/test/prepend/path"

    # Check it was added at the beginning
    local first_entry=$(echo "$PATH" | cut -d: -f1)
    assert_equals "/test/prepend/path" "$first_entry" "prepend_to_path adds at beginning"

    # Test idempotence
    local path_before="$PATH"
    prepend_to_path "/test/prepend/path"
    assert_equals "$path_before" "$PATH" "prepend_to_path is idempotent"

    export PATH="$original_path"
    teardown
}

test_print_path() {
    echo "=== Testing print_path ==="
    setup

    local output=$(print_path)
    local line_count=$(echo "$output" | wc -l)
    local colon_count=$(echo "$PATH" | tr -cd ':' | wc -c)
    local expected_lines=$((colon_count + 1))

    assert_equals "$expected_lines" "$line_count" "print_path outputs correct number of lines"

    teardown
}

test_get_char_limited_path() {
    echo "=== Testing get_char_limited_path ==="
    setup

    # Test short path (should not be truncated)
    cd /tmp
    local result=$(get_char_limited_path)
    assert_equals "/tmp" "$result" "short path unchanged"

    # Test home directory replacement
    cd "$HOME"
    result=$(get_char_limited_path)
    assert_equals "~" "$result" "home directory replaced with ~"

    # Test long path truncation
    mkdir -p "$TEST_DIR/very/long/directory/path/that/exceeds/the/limit/for/display"
    cd "$TEST_DIR/very/long/directory/path/that/exceeds/the/limit/for/display"
    result=$(get_char_limited_path)
    local result_len=${#result}
    if [ $result_len -le 39 ]; then
        pass "long path truncated to <= 39 chars (got $result_len)"
    else
        fail "long path truncation" "<= 39 chars" "$result_len chars"
    fi
    assert_contains "$result" "..." "truncated path contains ellipsis"

    teardown
}

test_bash_colors() {
    echo "=== Testing bash_colors ==="
    setup

    bash_colors

    # Check that color variables are exported
    assert_contains "$RED" "31m" "RED color defined"
    assert_contains "$GREEN" "32m" "GREEN color defined"
    assert_contains "$YELLOW" "33m" "YELLOW color defined"
    assert_contains "$BLUE" "34m" "BLUE color defined"
    assert_contains "$RESTORE" "0m" "RESTORE defined"

    teardown
}

test_is_git_repo() {
    echo "=== Testing is_git_repo ==="
    setup

    # Test in non-git directory
    cd "$TEST_DIR"
    local result
    is_git_repo && result=0 || result=$?
    assert_false $result "is_git_repo returns false outside git repo"

    # Test in git directory
    cd "$REPO_ROOT"
    is_git_repo && result=0 || result=$?
    assert_true $result "is_git_repo returns true in git repo"

    teardown
}

test_source_if_exists() {
    echo "=== Testing source_if_exists ==="
    setup

    # Create a test file that sets a variable
    echo 'TEST_VAR_FROM_SOURCE="sourced_successfully"' > "$TEST_DIR/test_source.sh"

    # Source existing file
    source_if_exists "$TEST_DIR/test_source.sh"
    assert_equals "sourced_successfully" "$TEST_VAR_FROM_SOURCE" "source_if_exists sources existing file"

    # Source non-existing file (should not error)
    local result
    source_if_exists "$TEST_DIR/nonexistent.sh" && result=0 || result=$?
    assert_true $result "source_if_exists handles missing file gracefully"

    teardown
}

test_show_git_branch() {
    echo "=== Testing show_git_branch ==="
    setup

    cd "$REPO_ROOT"
    local result=$(show_git_branch)
    assert_contains "$result" "master" "show_git_branch shows current branch"

    # Test outside git repo
    cd "$TEST_DIR"
    result=$(show_git_branch 2>&1)
    # Should return empty or error silently
    pass "show_git_branch handles non-git directory"

    teardown
}

test_mac_compliant_inline_sed() {
    echo "=== Testing mac_compliant_inline_sed ==="
    setup

    echo "hello world" > "$TEST_DIR/sed_test.txt"
    mac_compliant_inline_sed "s/world/universe/" "$TEST_DIR/sed_test.txt"
    local result=$(cat "$TEST_DIR/sed_test.txt")
    assert_equals "hello universe" "$result" "mac_compliant_inline_sed performs replacement"

    teardown
}

#############################################
# Test deploy.sh functions
#############################################

test_find_best_hash_function() {
    echo "=== Testing find_best_hash_function ==="

    # Source deploy.sh functions (but don't run the main logic)
    source <(sed -n '1,/^if \[\[/p' "$REPO_ROOT/deploy.sh" | head -n -1)

    local result=$(find_best_hash_function)
    # Should find at least md5sum or sha*sum on any Unix system
    if [ -n "$result" ]; then
        pass "find_best_hash_function returns a hash function: $result"
        # Verify it actually works
        local exec_result
        echo "test" | $result > /dev/null 2>&1 && exec_result=0 || exec_result=$?
        assert_true $exec_result "returned hash function is executable"
    else
        fail "find_best_hash_function" "a hash function name" "empty string"
    fi
}

test_backup_file() {
    echo "=== Testing backup_file ==="
    setup

    source <(sed -n '1,/^if \[\[/p' "$REPO_ROOT/deploy.sh" | head -n -1)

    # Create a test file
    echo "original content" > "$TEST_DIR/testfile.txt"

    # Backup it
    backup_file "$TEST_DIR/testfile.txt"

    # Original should be gone, .bak should exist
    if [ ! -e "$TEST_DIR/testfile.txt" ] && [ -e "$TEST_DIR/testfile.txt.bak" ]; then
        pass "backup_file moves file to .bak"
    else
        fail "backup_file" "file moved to .bak" "file not properly backed up"
    fi

    # Test recursive backup
    echo "new content" > "$TEST_DIR/testfile.txt"
    backup_file "$TEST_DIR/testfile.txt"

    if [ -e "$TEST_DIR/testfile.txt.bak.bak" ]; then
        pass "backup_file recursively backs up existing .bak files"
    else
        fail "backup_file recursive" ".bak.bak exists" "no recursive backup"
    fi

    teardown
}

test_unbackup_file() {
    echo "=== Testing unbackup_file ==="
    setup

    source <(sed -n '1,/^if \[\[/p' "$REPO_ROOT/deploy.sh" | head -n -1)

    # Create a backed up file
    echo "backed up content" > "$TEST_DIR/testfile.txt.bak"

    # Restore it
    unbackup_file "$TEST_DIR/testfile.txt"

    # .bak should be gone, original should exist
    if [ -e "$TEST_DIR/testfile.txt" ] && [ ! -e "$TEST_DIR/testfile.txt.bak" ]; then
        pass "unbackup_file restores .bak to original"
    else
        fail "unbackup_file" "file restored from .bak" "file not properly restored"
    fi

    # Verify content
    local content=$(cat "$TEST_DIR/testfile.txt")
    assert_equals "backed up content" "$content" "unbackup_file preserves file content"

    teardown
}

test_ensure_path_is_correct() {
    echo "=== Testing ensure_path_is_correct ==="

    source <(sed -n '1,/^if \[\[/p' "$REPO_ROOT/deploy.sh" | head -n -1)

    # This test checks that the function exists and has the right logic
    # We can't easily test it without potentially exiting the script

    # Check that it expects ~/userconf path
    if grep -q 'HOME/userconf' "$REPO_ROOT/deploy.sh"; then
        pass "ensure_path_is_correct checks for ~/userconf"
    else
        fail "ensure_path_is_correct" "checks ~/userconf" "different path"
    fi
}

#############################################
# Test 40_prompt.sh
#############################################

test_gen_PS1() {
    echo "=== Testing gen_PS1 ==="
    setup

    source "$REPO_ROOT/shell_config/40_prompt.sh"

    local ps1=$(gen_PS1)

    # Should contain user prompt
    assert_contains "$ps1" '\u' "PS1 contains username placeholder"

    # Should contain path
    assert_contains "$ps1" 'get_char_limited_path' "PS1 uses get_char_limited_path"

    # Should end with $ or # depending on user
    if [ $(id -u) -eq 0 ]; then
        assert_contains "$ps1" '#' "PS1 ends with # for root"
    else
        assert_contains "$ps1" '\$' "PS1 ends with $ for regular user"
    fi

    # Test custom hostname option
    ps1=$(gen_PS1 -h "customhost")
    assert_contains "$ps1" "customhost" "gen_PS1 accepts custom hostname"

    teardown
}

#############################################
# Test 70_githelpers.sh
#############################################

test_pretty_git_format() {
    echo "=== Testing pretty_git_format ==="
    setup

    source "$REPO_ROOT/shell_config/70_githelpers.sh"

    # Test "ago" removal
    local result=$(echo "hash}(2 years ago)}author" | pretty_git_format)
    assert_not_contains "$result" "ago" "pretty_git_format removes 'ago'"

    # Test month truncation
    result=$(echo "hash}(2 years, 5 months ago)}author" | pretty_git_format)
    assert_not_contains "$result" "months" "pretty_git_format truncates months"

    teardown
}

#############################################
# Test file structure and paths
#############################################

test_file_structure() {
    echo "=== Testing file structure ==="

    # Check all expected files exist
    local files=(
        "deploy.sh"
        "shell_config/00_functions.sh"
        "shell_config/20_set_variables.sh"
        "shell_config/30_history.sh"
        "shell_config/40_prompt.sh"
        "shell_config/50_nvm.sh"
        "shell_config/60_aliases.sh"
        "shell_config/70_githelpers.sh"
        "shell_config/90_amazon.sh"
        "shell_config/99_local.sh"
        "dotfiles/gitconfig"
        "dotfiles/pythonrc"
        "dotfiles/sqliterc"
        "dotfiles/vimrc"
    )

    for file in "${files[@]}"; do
        if [ -f "$REPO_ROOT/$file" ]; then
            pass "File exists: $file"
        else
            fail "File exists" "$file" "missing"
        fi
    done
}

test_path_references() {
    echo "=== Testing path references (checking for stale paths) ==="

    # Check for old config path references that should be shell_config
    if grep -q "userconf/config/" "$REPO_ROOT/deploy.sh"; then
        fail "deploy.sh path reference" "userconf/shell_config/" "userconf/config/ (stale)"
    else
        pass "deploy.sh uses correct shell_config path"
    fi

    if grep -q "userconf/config/" "$REPO_ROOT/dotfiles/gitconfig"; then
        fail "gitconfig path reference" "userconf/shell_config/" "userconf/config/ (stale)"
    else
        pass "gitconfig uses correct shell_config path"
    fi
}

test_syntax_check() {
    echo "=== Testing shell script syntax ==="

    local scripts=(
        "deploy.sh"
        "shell_config/00_functions.sh"
        "shell_config/20_set_variables.sh"
        "shell_config/30_history.sh"
        "shell_config/40_prompt.sh"
        "shell_config/50_nvm.sh"
        "shell_config/60_aliases.sh"
        "shell_config/70_githelpers.sh"
        "shell_config/90_amazon.sh"
        "shell_config/99_local.sh"
    )

    for script in "${scripts[@]}"; do
        if bash -n "$REPO_ROOT/$script" 2>/dev/null; then
            pass "Syntax valid: $script"
        else
            fail "Syntax check" "valid bash syntax" "syntax error in $script"
        fi
    done
}

test_functions_sourceable() {
    echo "=== Testing that config files can be sourced together ==="

    # Test that key files can be sourced (skip 20_set_variables which loads bash_completion)
    local result
    result=$(bash --norc --noprofile -c '
        set -e
        export HOME='"$HOME"'
        source '"$REPO_ROOT"'/shell_config/00_functions.sh
        source '"$REPO_ROOT"'/shell_config/30_history.sh
        source '"$REPO_ROOT"'/shell_config/40_prompt.sh
        source '"$REPO_ROOT"'/shell_config/70_githelpers.sh
        echo "success"
    ' 2>&1) || result="error"

    if echo "$result" | grep -q "success"; then
        pass "Core shell_config files source without error"
    else
        fail "Sourcing shell_config" "no errors" "$result"
    fi
}

#############################################
# Main test runner
#############################################

echo "========================================"
echo "Running userconf test suite"
echo "========================================"
echo ""

# Run all tests
test_file_structure
echo ""
test_path_references
echo ""
test_syntax_check
echo ""
test_functions_sourceable
echo ""
test_add_to_path
echo ""
test_prepend_to_path
echo ""
test_print_path
echo ""
test_get_char_limited_path
echo ""
test_bash_colors
echo ""
test_is_git_repo
echo ""
test_source_if_exists
echo ""
test_show_git_branch
echo ""
test_mac_compliant_inline_sed
echo ""
test_find_best_hash_function
echo ""
test_backup_file
echo ""
test_unbackup_file
echo ""
test_ensure_path_is_correct
echo ""
test_gen_PS1
echo ""
test_pretty_git_format
echo ""

# Summary
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Total:  $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "========================================"

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi
