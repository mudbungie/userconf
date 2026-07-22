#!/bin/bash
#
# deploy.sh rc-file hooks: inject_rc_line and the rc-file set it installs.
#

test_inject_rc_line() {
    echo "=== Testing inject_rc_line ==="
    setup
    source_deploy_functions

    local line='. ~/userconf/orb_profile'

    # Creates a missing file.
    inject_rc_line "$TEST_DIR/newrc" "$line" >/dev/null
    if [ -f "$TEST_DIR/newrc" ] && grep -qF "$line" "$TEST_DIR/newrc"; then
        pass "inject_rc_line creates a missing rc file containing the line"
    else
        fail "inject_rc_line create" "file with line" "missing or no line"
    fi

    # Prepends to an existing file, keeping what was there.
    echo "# existing content" > "$TEST_DIR/existingrc"
    inject_rc_line "$TEST_DIR/existingrc" "$line" >/dev/null
    assert_equals "$line" "$(head -n 1 "$TEST_DIR/existingrc")" \
        "inject_rc_line prepends to an existing file"
    assert_contains "$(cat "$TEST_DIR/existingrc")" "existing content" \
        "inject_rc_line preserves the file's other content"

    # Idempotent: re-running adds nothing.
    local before after
    before=$(grep -cF "$line" "$TEST_DIR/existingrc")
    inject_rc_line "$TEST_DIR/existingrc" "$line" >/dev/null
    after=$(grep -cF "$line" "$TEST_DIR/existingrc")
    assert_equals "$before" "$after" "inject_rc_line is idempotent"

    # The line is a parameter, not a constant.
    inject_rc_line "$TEST_DIR/bridgerc" '[ -f ~/.bashrc ] && . ~/.bashrc' >/dev/null
    assert_contains "$(cat "$TEST_DIR/bridgerc")" 'bashrc' \
        "inject_rc_line injects whatever line it is given"

    teardown
}

test_install_shell_hooks_rc_set() {
    echo "=== Testing the set of rc files hooked ==="
    setup
    source_deploy_functions

    local original_home="$HOME"
    export HOME="$TEST_DIR"
    install_shell_hooks >/dev/null

    # Three hooks, not five.
    local f
    for f in .bashrc .bash_profile .zshrc; do
        if [ -f "$TEST_DIR/$f" ]; then
            pass "install_shell_hooks writes ~/$f"
        else
            fail "install_shell_hooks" "~/$f written" "missing"
        fi
    done
    for f in .zprofile .profile; do
        if [ -e "$TEST_DIR/$f" ]; then
            fail "install_shell_hooks" "~/$f left alone" "written"
        else
            pass "install_shell_hooks does not touch ~/$f"
        fi
    done

    # .bashrc and .zshrc source orb_profile directly.
    assert_contains "$(cat "$TEST_DIR/.bashrc")" 'userconf/orb_profile' \
        ".bashrc sources orb_profile"
    assert_contains "$(cat "$TEST_DIR/.zshrc")" 'userconf/orb_profile' \
        ".zshrc sources orb_profile"

    # .bash_profile is a bridge to .bashrc, NOT a second entrypoint: a login
    # bash (every macOS Terminal tab) never reads .bashrc on its own.
    assert_contains "$(cat "$TEST_DIR/.bash_profile")" '\. ~/\.bashrc' \
        ".bash_profile bridges to .bashrc"
    assert_not_contains "$(cat "$TEST_DIR/.bash_profile")" 'orb_profile' \
        ".bash_profile does not add a second orb_profile entrypoint"

    export HOME="$original_home"
    teardown
}

test_install_shell_hooks_idempotent() {
    echo "=== Testing install_shell_hooks idempotence ==="
    setup
    source_deploy_functions

    local original_home="$HOME"
    export HOME="$TEST_DIR"

    install_shell_hooks >/dev/null
    local first
    first=$(cat "$TEST_DIR/.bashrc" "$TEST_DIR/.bash_profile" "$TEST_DIR/.zshrc")
    install_shell_hooks >/dev/null
    local second
    second=$(cat "$TEST_DIR/.bashrc" "$TEST_DIR/.bash_profile" "$TEST_DIR/.zshrc")

    assert_equals "$first" "$second" "install_shell_hooks is a no-op on re-run"

    export HOME="$original_home"
    teardown
}
