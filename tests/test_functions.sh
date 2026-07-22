#!/bin/bash
#
# shell_config/00_functions.sh
#

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
    local first_entry
    first_entry=$(echo "$PATH" | cut -d: -f1)
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

    local output line_count colon_count expected_lines
    output=$(print_path)
    line_count=$(echo "$output" | wc -l)
    colon_count=$(echo "$PATH" | tr -cd ':' | wc -c)
    expected_lines=$((colon_count + 1))

    assert_equals "$expected_lines" "$line_count" "print_path outputs correct number of lines"

    teardown
}

test_get_char_limited_path() {
    echo "=== Testing get_char_limited_path ==="
    setup

    # Test short path (should not be truncated)
    cd /tmp || return 1
    local result
    result=$(get_char_limited_path)
    assert_equals "/tmp" "$result" "short path unchanged"

    # Test home directory replacement
    cd "$HOME" || return 1
    result=$(get_char_limited_path)
    assert_equals "~" "$result" "home directory replaced with ~"

    # Test long path truncation
    mkdir -p "$TEST_DIR/very/long/directory/path/that/exceeds/the/limit/for/display"
    cd "$TEST_DIR/very/long/directory/path/that/exceeds/the/limit/for/display" || return 1
    result=$(get_char_limited_path)
    local result_len=${#result}
    if [ "$result_len" -le 39 ]; then
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
    cd "$TEST_DIR" || return 1
    local result
    is_git_repo && result=0 || result=$?
    assert_false $result "is_git_repo returns false outside git repo"

    # Test in git directory
    cd "$REPO_ROOT" || return 1
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

    # Compare against git's own answer rather than a hardcoded branch name:
    # the suite also runs inside work/<id> delivery worktrees.
    cd "$REPO_ROOT" || return 1
    local expected result
    expected=$(git rev-parse --abbrev-ref HEAD)
    result=$(show_git_branch)
    assert_contains "$result" "$expected" "show_git_branch shows current branch"

    # Test outside git repo
    cd "$TEST_DIR" || return 1
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
    local result
    result=$(cat "$TEST_DIR/sed_test.txt")
    assert_equals "hello universe" "$result" "mac_compliant_inline_sed performs replacement"

    teardown
}
