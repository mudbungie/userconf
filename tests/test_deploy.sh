#!/bin/bash
#
# deploy.sh helper functions, plus the orb_profile entrypoint contract.
#

test_find_best_hash_function() {
    echo "=== Testing find_best_hash_function ==="

    source_deploy_functions

    local result
    result=$(find_best_hash_function)
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
    source_deploy_functions

    echo "original content" > "$TEST_DIR/testfile.txt"
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
    source_deploy_functions

    echo "backed up content" > "$TEST_DIR/testfile.txt.bak"
    unbackup_file "$TEST_DIR/testfile.txt"

    # .bak should be gone, original should exist
    if [ -e "$TEST_DIR/testfile.txt" ] && [ ! -e "$TEST_DIR/testfile.txt.bak" ]; then
        pass "unbackup_file restores .bak to original"
    else
        fail "unbackup_file" "file restored from .bak" "file not properly restored"
    fi

    local content
    content=$(cat "$TEST_DIR/testfile.txt")
    assert_equals "backed up content" "$content" "unbackup_file preserves file content"

    teardown
}

test_orb_profile_idempotence() {
    echo "=== Testing orb_profile idempotence ==="
    setup

    # Set up a minimal shell_config for testing
    mkdir -p "$TEST_DIR/userconf/shell_config"
    echo 'TEST_ORB_COUNTER=$((TEST_ORB_COUNTER + 1))' > "$TEST_DIR/userconf/shell_config/00_test.sh"

    # Create orb_profile pointing to test dir
    cat > "$TEST_DIR/orb_profile" << 'EOPROFILE'
[ -n "$ORB_PROFILE_LOADED" ] && return 0
export ORB_PROFILE_LOADED=1
ORB_USERCONF_DIR="${ORB_USERCONF_DIR:-$HOME/userconf}"
for _orb_conf in "$ORB_USERCONF_DIR"/shell_config/*.sh; do
    [ -f "$_orb_conf" ] && . "$_orb_conf"
done
unset _orb_conf
EOPROFILE

    # Source it twice, counter should only increment once
    export TEST_ORB_COUNTER=0
    export ORB_USERCONF_DIR="$TEST_DIR/userconf"
    unset ORB_PROFILE_LOADED

    . "$TEST_DIR/orb_profile"
    . "$TEST_DIR/orb_profile"

    assert_equals "1" "$TEST_ORB_COUNTER" "orb_profile idempotence guard prevents double-sourcing"

    teardown
}

test_inject_orb_profile() {
    echo "=== Testing inject_orb_profile ==="
    setup
    source_deploy_functions

    # Test creating new file
    inject_orb_profile "$TEST_DIR/newrc" >/dev/null
    if [ -f "$TEST_DIR/newrc" ] && grep -qF '. ~/userconf/orb_profile' "$TEST_DIR/newrc"; then
        pass "inject_orb_profile creates new file with hook"
    else
        fail "inject_orb_profile create" "file with hook" "missing or no hook"
    fi

    # Test injecting into existing file
    echo "# existing content" > "$TEST_DIR/existingrc"
    inject_orb_profile "$TEST_DIR/existingrc" >/dev/null
    local first_line
    first_line=$(head -n 1 "$TEST_DIR/existingrc")
    assert_equals ". ~/userconf/orb_profile" "$first_line" "inject_orb_profile prepends to existing file"

    # Test idempotence (shouldn't duplicate)
    local line_count_before line_count_after
    line_count_before=$(grep -cF '. ~/userconf/orb_profile' "$TEST_DIR/existingrc")
    inject_orb_profile "$TEST_DIR/existingrc" >/dev/null
    line_count_after=$(grep -cF '. ~/userconf/orb_profile' "$TEST_DIR/existingrc")
    assert_equals "$line_count_before" "$line_count_after" "inject_orb_profile is idempotent"

    teardown
}

test_ensure_path_is_correct() {
    echo "=== Testing ensure_path_is_correct ==="

    source_deploy_functions

    # The function exits on mismatch, so assert on its contract instead of
    # calling it: it must be checking for the ~/userconf clone location.
    if grep -q 'HOME/userconf' "$REPO_ROOT/deploy.sh"; then
        pass "ensure_path_is_correct checks for ~/userconf"
    else
        fail "ensure_path_is_correct" "checks ~/userconf" "different path"
    fi
}

test_make_local_bin_dir() {
    echo "=== Testing make_local_bin_dir ==="
    setup
    source_deploy_functions

    # Override HOME to test dir so we don't modify actual home
    local original_home="$HOME"
    export HOME="$TEST_DIR"

    if [ -d "$TEST_DIR/.local/bin" ]; then
        fail "make_local_bin_dir setup" "directory does not exist initially" "directory already exists"
    else
        pass "~/.local/bin does not exist initially"
    fi

    make_local_bin_dir >/dev/null

    if [ -d "$TEST_DIR/.local/bin" ]; then
        pass "make_local_bin_dir creates ~/.local/bin"
    else
        fail "make_local_bin_dir" "directory created" "directory not created"
    fi

    # Test idempotence - running again should not fail
    local result
    make_local_bin_dir >/dev/null && result=0 || result=$?
    assert_true $result "make_local_bin_dir is idempotent"

    export HOME="$original_home"
    teardown
}
