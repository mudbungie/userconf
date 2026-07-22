#!/bin/bash
#
# Dotfile deployment: backup_file, link_dotfile, install_dotfiles.
# Deploy links dotfiles/<name> to $HOME/.<name>, so the repo is the only home
# for the fact and idempotence is structural.
#

test_backup_file() {
    echo "=== Testing backup_file ==="
    setup
    source_deploy_functions

    echo "original content" > "$TEST_DIR/testfile.txt"
    backup_file "$TEST_DIR/testfile.txt" >/dev/null

    if [ ! -e "$TEST_DIR/testfile.txt" ] && [ -e "$TEST_DIR/testfile.txt.bak" ]; then
        pass "backup_file moves file to .bak"
    else
        fail "backup_file" "file moved to .bak" "file not properly backed up"
    fi

    # An existing .bak is the true original: refuse, never chain.
    echo "new content" > "$TEST_DIR/testfile.txt"
    local result
    backup_file "$TEST_DIR/testfile.txt" >/dev/null 2>&1 && result=0 || result=$?
    assert_false $result "backup_file refuses when a .bak already exists"
    assert_equals "original content" "$(cat "$TEST_DIR/testfile.txt.bak")" \
        "backup_file does not overwrite the existing .bak"
    if [ -e "$TEST_DIR/testfile.txt.bak.bak" ]; then
        fail "backup_file" "no .bak.bak chain" ".bak.bak created"
    else
        pass "backup_file builds no .bak.bak chain"
    fi

    # Nothing to do for a file that is not there.
    backup_file "$TEST_DIR/absent" >/dev/null 2>&1 && result=0 || result=$?
    assert_true $result "backup_file is a no-op on a missing file"

    teardown
}

test_link_dotfile() {
    echo "=== Testing link_dotfile ==="
    setup
    source_deploy_functions

    echo "repo version" > "$TEST_DIR/src"

    # Absent target: just link.
    link_dotfile "$TEST_DIR/src" "$TEST_DIR/dest" >/dev/null
    assert_equals "$TEST_DIR/src" "$(readlink "$TEST_DIR/dest")" \
        "link_dotfile links an absent target"

    # Correct link already in place: no-op, and no .bak invented.
    link_dotfile "$TEST_DIR/src" "$TEST_DIR/dest" >/dev/null
    assert_equals "$TEST_DIR/src" "$(readlink "$TEST_DIR/dest")" \
        "link_dotfile leaves a correct link alone"
    if [ -e "$TEST_DIR/dest.bak" ]; then
        fail "link_dotfile" "no backup of a correct link" "dest.bak created"
    else
        pass "link_dotfile does not back up a link it already owns"
    fi

    # A foreign symlink is displaced like any other file.
    ln -s "$TEST_DIR/src" "$TEST_DIR/other"
    ln -s "$TEST_DIR/other" "$TEST_DIR/foreign"
    link_dotfile "$TEST_DIR/src" "$TEST_DIR/foreign" >/dev/null
    assert_equals "$TEST_DIR/src" "$(readlink "$TEST_DIR/foreign")" \
        "link_dotfile replaces a foreign symlink"
    assert_equals "$TEST_DIR/other" "$(readlink "$TEST_DIR/foreign.bak")" \
        "link_dotfile preserves the foreign symlink as .bak"

    # Refuses rather than destroying a second original.
    rm "$TEST_DIR/foreign"
    echo "second original" > "$TEST_DIR/foreign"
    local result
    link_dotfile "$TEST_DIR/src" "$TEST_DIR/foreign" >/dev/null 2>&1 && result=0 || result=$?
    assert_false $result "link_dotfile refuses when the .bak slot is taken"
    assert_equals "second original" "$(cat "$TEST_DIR/foreign")" \
        "link_dotfile leaves the target untouched when it refuses"

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
    echo "repo vim" > "$TEST_DIR/repo/dotfiles/vimrc"
    echo "precious user data" > "$HOME/.gitconfig"

    cd "$TEST_DIR/repo" || return 1
    install_dotfiles >/dev/null

    assert_equals "precious user data" "$(cat "$HOME/.gitconfig.bak" 2>/dev/null)" \
        "install_dotfiles backs up the real \$HOME dotfile it displaces"
    assert_equals "$TEST_DIR/repo/dotfiles/gitconfig" "$(readlink "$HOME/.gitconfig")" \
        "install_dotfiles symlinks to the repo, absolute"
    assert_equals "$TEST_DIR/repo/dotfiles/vimrc" "$(readlink "$HOME/.vimrc")" \
        "install_dotfiles links every dotfile"

    # The repo is the only home: an edit through the link lands in the repo.
    echo "edited live" > "$HOME/.vimrc"
    assert_equals "edited live" "$(cat "$TEST_DIR/repo/dotfiles/vimrc")" \
        "an edit through the link reaches the repo file"

    # Re-run is structurally a no-op: no chain, no clobber.
    install_dotfiles >/dev/null
    assert_equals "$TEST_DIR/repo/dotfiles/gitconfig" "$(readlink "$HOME/.gitconfig")" \
        "install_dotfiles is idempotent"
    if [ -e "$HOME/.gitconfig.bak.bak" ] || [ -e "$HOME/.vimrc.bak" ]; then
        fail "install_dotfiles re-run" "no new backups" ".bak accumulated"
    else
        pass "re-running install_dotfiles accumulates no .bak files"
    fi
    assert_equals "precious user data" "$(cat "$HOME/.gitconfig.bak")" \
        "the original backup survives a re-run"

    # The quoted tilde used to create a literal ./~ directory instead.
    if [ -e "$TEST_DIR/repo/~" ]; then
        fail "install_dotfiles" "no literal ~ directory" "created ./~"
    else
        pass "install_dotfiles does not create a literal ~ path"
    fi

    export HOME="$original_home"
    teardown
}
