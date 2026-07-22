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

    # A minimal shell_config that counts how many times it was loaded.
    mkdir -p "$TEST_DIR/userconf/shell_config"
    echo 'TEST_ORB_COUNTER=$((TEST_ORB_COUNTER + 1))' \
        > "$TEST_DIR/userconf/shell_config/00_test.sh"

    # Exercise the real entrypoint, not a copy of it.
    TEST_ORB_COUNTER=0
    ORB_USERCONF_DIR="$TEST_DIR/userconf"
    unset ORB_PROFILE_LOADED

    . "$REPO_ROOT/orb_profile"
    . "$REPO_ROOT/orb_profile"

    assert_equals "1" "$TEST_ORB_COUNTER" "orb_profile idempotence guard prevents double-sourcing"

    unset ORB_PROFILE_LOADED ORB_USERCONF_DIR TEST_ORB_COUNTER
    teardown
}

test_orb_profile_guard_not_exported() {
    echo "=== Testing orb_profile guard is not inherited ==="
    setup

    # An exported guard is inherited by child shells, which then skip loading
    # every config file - a nested shell would get no configuration at all.
    mkdir -p "$TEST_DIR/userconf/shell_config"
    echo 'ORB_CHILD_MARKER=loaded' > "$TEST_DIR/userconf/shell_config/00_test.sh"

    local result
    # env -u: the invoking shell may itself have been configured by orb_profile.
    result=$(env -u ORB_PROFILE_LOADED ORB_USERCONF_DIR="$TEST_DIR/userconf" \
        bash --norc --noprofile -c '
        . "'"$REPO_ROOT"'/orb_profile"
        bash --norc --noprofile -c "echo \${ORB_PROFILE_LOADED:-unset}"
    ')
    assert_equals "unset" "$result" "ORB_PROFILE_LOADED is not exported to child shells"

    # And the consequence: a child shell still loads the configuration.
    result=$(env -u ORB_PROFILE_LOADED ORB_USERCONF_DIR="$TEST_DIR/userconf" \
        bash --norc --noprofile -c '
        . "'"$REPO_ROOT"'/orb_profile"
        bash --norc --noprofile -c ". \"'"$REPO_ROOT"'/orb_profile\"; echo \$ORB_CHILD_MARKER"
    ')
    assert_equals "loaded" "$result" "a nested shell still loads shell_config"

    teardown
}

test_ps1_not_exported() {
    echo "=== Testing PS1 is not exported ==="
    setup

    local result
    result=$(env -u PS1 bash --norc --noprofile -c '
        . "'"$REPO_ROOT"'/shell_config/00_functions.sh"
        . "'"$REPO_ROOT"'/shell_config/40_prompt.sh"
        [ -n "$PS1" ] || echo "PS1 UNSET IN OWN SHELL"
        bash --norc --noprofile -c "echo \${PS1:-unset}"
    ')
    assert_equals "unset" "$result" "PS1 is set locally but not exported to children"

    teardown
}

test_install_dotfiles() {
    echo "=== Testing install_dotfiles ==="
    setup
    source_deploy_functions

    local original_home="$HOME"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME" "$TEST_DIR/repo/dotfiles"
    echo "repo version" > "$TEST_DIR/repo/dotfiles/gitconfig"
    echo "precious user data" > "$HOME/.gitconfig"

    cd "$TEST_DIR/repo" || return 1
    install_dotfiles >/dev/null

    assert_equals "precious user data" "$(cat "$HOME/.gitconfig.bak" 2>/dev/null)" \
        "install_dotfiles backs up the real \$HOME dotfile before clobbering it"
    assert_equals "repo version" "$(cat "$HOME/.gitconfig")" \
        "install_dotfiles installs the repo copy"

    # The quoted tilde used to create a literal ./~ directory instead.
    if [ -e "$TEST_DIR/repo/~" ]; then
        fail "install_dotfiles" "no literal ~ directory" "created ./~"
    else
        pass "install_dotfiles does not create a literal ~ path"
    fi

    export HOME="$original_home"
    teardown
}

# A fake package manager that just reports how it was invoked.
_fake_bin() {
    local dir="$1" name="$2"
    printf '#!/bin/sh\necho "%s $*"\n' "$name" > "$dir/$name"
    chmod +x "$dir/$name"
}

test_install_packages_detection() {
    echo "=== Testing install_packages ==="
    setup
    source_deploy_functions

    local bin="$TEST_DIR/bin"
    mkdir -p "$bin"
    ln -s "$(command -v id)" "$bin/id"

    # No package manager anywhere: `[ !$pkgmgr ]` used to be always-true, so
    # this path was never reached and install ran with an empty command.
    local result
    ( PATH="$bin"; install_packages ) >/dev/null 2>&1 && result=0 || result=$?
    assert_equals "2" "$result" "install_packages returns 2 when no package manager is found"

    # First match in the preference list wins, not the last.
    _fake_bin "$bin" apt
    _fake_bin "$bin" brew
    printf '#!/bin/sh\nexec "$@"\n' > "$bin/sudo"
    chmod +x "$bin/sudo"

    local output
    output=$( PATH="$bin"; install_packages 2>&1 )
    assert_contains "$output" "apt install -y vim" "install_packages keeps the first manager found (apt over brew)"
    assert_not_contains "$output" "brew install" "install_packages does not fall through to a later manager"

    # brew has no -y flag and must not be run under sudo.
    rm "$bin/apt"
    output=$( PATH="$bin"; install_packages 2>&1 )
    assert_contains "$output" "brew install vim" "brew is invoked without -y"
    assert_not_contains "$output" "brew install -y" "brew is not given the invalid -y flag"

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
