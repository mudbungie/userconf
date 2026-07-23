#!/bin/bash
#
# deploy.sh helper functions, plus the orb_profile entrypoint contract.
#

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

test_orb_profile_guard_is_pid_stamped() {
    echo "=== Testing a foreign guard value does not suppress loading ==="
    setup

    mkdir -p "$TEST_DIR/userconf/shell_config"
    echo 'ORB_CHILD_MARKER=loaded' > "$TEST_DIR/userconf/shell_config/00_test.sh"

    # The defect this ball fixes. d8dfcc2 shipped `export ORB_PROFILE_LOADED=1`
    # and fe70e77 removed the export, but a desktop session started in between
    # keeps handing the exported 1 to every shell beneath it until logout. A
    # guard that only asks "is it set?" reads that as "already done" and loads
    # nothing at all, silently. A pid stamp cannot be inherited into a match.
    local result
    result=$(ORB_PROFILE_LOADED=1 ORB_USERCONF_DIR="$TEST_DIR/userconf" \
        bash --norc --noprofile -c '
        . "'"$REPO_ROOT"'/orb_profile"
        echo "${ORB_CHILD_MARKER:-nothing-loaded}"
    ')
    assert_equals "loaded" "$result" \
        "an inherited ORB_PROFILE_LOADED=1 does not stop shell_config loading"

    # Any foreign value, not just the historical 1 - including another shell's
    # pid, which is exactly what an exported stamp would look like.
    result=$(ORB_PROFILE_LOADED=999999 ORB_USERCONF_DIR="$TEST_DIR/userconf" \
        bash --norc --noprofile -c '
        . "'"$REPO_ROOT"'/orb_profile"
        echo "${ORB_CHILD_MARKER:-nothing-loaded}"
    ')
    assert_equals "loaded" "$result" \
        "a foreign pid in the guard does not stop shell_config loading either"

    # And the guard still does its own job: this shell, sourcing twice.
    result=$(env -u ORB_PROFILE_LOADED ORB_USERCONF_DIR="$TEST_DIR/userconf" \
        bash --norc --noprofile -c '
        . "'"$REPO_ROOT"'/orb_profile"
        ORB_CHILD_MARKER=
        . "'"$REPO_ROOT"'/orb_profile"
        echo "${ORB_CHILD_MARKER:-second-source-skipped}"
    ')
    assert_equals "second-source-skipped" "$result" \
        "the same shell sourcing twice still short-circuits"

    teardown
}

test_ps1_not_exported() {
    echo "=== Testing PS1 is not exported ==="
    setup

    local result
    result=$(env -u PS1 bash --norc --noprofile -c '
        . "'"$REPO_ROOT"'/shell_config/00_functions.sh"
        . "'"$REPO_ROOT"'/shell_config/40_prompt.bash.interactive.sh"
        [ -n "$PS1" ] || echo "PS1 UNSET IN OWN SHELL"
        bash --norc --noprofile -c "echo \${PS1:-unset}"
    ')
    assert_equals "unset" "$result" "PS1 is set locally but not exported to children"

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
    assert_contains "$output" "apt install -y git" "install_packages keeps the first manager found (apt over brew)"
    assert_not_contains "$output" "brew install" "install_packages does not fall through to a later manager"

    # brew has no -y flag and must not be run under sudo.
    rm "$bin/apt"
    output=$( PATH="$bin"; install_packages 2>&1 )
    assert_contains "$output" "brew install git" "brew is invoked without -y"
    assert_not_contains "$output" "brew install -y" "brew is not given the invalid -y flag"

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
