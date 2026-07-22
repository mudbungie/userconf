#!/bin/bash
#
# Git identity is machine-local (D3): dotfiles/gitconfig ships the shared base
# and includes ~/.gitconfig_local, which deploy.sh creates if absent and never
# overwrites.
#
# The real $HOME is never touched: every case runs with HOME repointed at the
# sandbox, and XDG_CONFIG_HOME/GIT_CONFIG_* cleared so the machine's own git
# config cannot leak in.
#

GITCONFIG_ALIASES=(a aa ca ci cia co di dic di1 st ff pff noff fa p po pom
                   poma poml pod l r ra head h b)

test_gitconfig_ships_no_identity() {
    echo "=== Testing that dotfiles/gitconfig ships no identity ==="

    local config
    config=$(cat "$REPO_ROOT/dotfiles/gitconfig")

    assert_not_contains "$config" '^\[user\]' "dotfiles/gitconfig has no [user] section"
    assert_not_contains "$config" 'mudbungie' "dotfiles/gitconfig names no person"
    assert_not_contains "$config" '@' "dotfiles/gitconfig carries no email address"

    # The shared base survives in full.
    local section
    for section in core init color merge format alias include; do
        assert_contains "$config" "^\[$section\]" "dotfiles/gitconfig keeps [$section]"
    done
    local alias_name
    for alias_name in "${GITCONFIG_ALIASES[@]}"; do
        assert_contains "$config" "^    $alias_name = " "alias '$alias_name' survives"
    done
}

test_gitconfig_includes_local_last() {
    echo "=== Testing the [include] of the machine-local file ==="

    local config
    config=$(cat "$REPO_ROOT/dotfiles/gitconfig")
    assert_contains "$config" '^    path = ~/\.gitconfig_local$' \
        "dotfiles/gitconfig includes ~/.gitconfig_local"

    # Last word wins in git config, so the include must be the final section or
    # the base would override the machine's own settings.
    assert_equals "[include]" "$(grep '^\[' "$REPO_ROOT/dotfiles/gitconfig" | tail -1)" \
        "[include] is the last section, so the local file overrides the base"
}

test_githelper_aliases_still_resolve() {
    echo "=== Testing that git l / git b still resolve ==="
    setup

    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"
    # The aliases hardcode ~/userconf, so the sandbox HOME needs that name.
    ln -s "$REPO_ROOT" "$HOME/userconf"
    ln -s "$REPO_ROOT/dotfiles/gitconfig" "$HOME/.gitconfig"
    printf '[user]\n\tname = Sandbox\n\temail = sandbox@example.invalid\n' \
        > "$HOME/.gitconfig_local"

    local repo="$TEST_DIR/scratchrepo"
    mkdir -p "$repo"
    (
        cd "$repo" || exit 1
        git init -q
        echo hello > file.txt
        git add file.txt
        git commit -q -m "a commit subject"
    ) >/dev/null 2>&1

    # The include is what supplies the identity: the commit above cannot exist
    # without it, since the tracked base has no [user] at all.
    assert_equals "sandbox@example.invalid" \
        "$(cd "$repo" && git config user.email)" \
        "the [include] pulls identity out of ~/.gitconfig_local"
    assert_equals "Sandbox" "$(cd "$repo" && git log -1 --format=%an)" \
        "a commit made under the shipped gitconfig uses the local identity"

    local out
    out=$(cd "$repo" && GIT_NO_PAGER=1 git l 2>&1)
    assert_contains "$out" "a commit subject" "git l still runs 70_githelpers.sh"
    out=$(cd "$repo" && git b 2>&1)
    assert_contains "$out" "a commit subject" "git b still runs 70_githelpers.sh"

    teardown
}

# Run install_git_local_config against a sandbox HOME with no git config of any
# kind visible to it.
_run_install_git_local_config() {
    env -u XDG_CONFIG_HOME -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_SYSTEM \
        HOME="$TEST_DIR/home" \
        bash -c "source <(sed -n '1,/^if \[\[/p' '$REPO_ROOT/deploy.sh' | head -n -1)
                 install_git_local_config" 2>&1
}

test_install_git_local_config_creates() {
    echo "=== Testing install_git_local_config on a bare machine ==="
    setup

    mkdir -p "$TEST_DIR/home"
    local out
    out=$(_run_install_git_local_config)
    assert_contains "$out" "WARNING" "an identity-less machine is warned about, loudly"

    local created="$TEST_DIR/home/.gitconfig_local"
    assert_contains "$(cat "$created")" '^#    name = ' \
        "the [user] fields are commented out, not filled with a fake name"
    # A real placeholder would let git commit as "Your Name"; a commented one
    # makes git ask, which is the honest failure.
    assert_equals "" "$(git config --file "$created" --get user.name)" \
        "no identity is invented"

    teardown
}

test_install_git_local_config_seeds_and_never_overwrites() {
    echo "=== Testing install_git_local_config seeding and idempotence ==="
    setup

    mkdir -p "$TEST_DIR/home"
    # The identity this machine already had, in the real ~/.gitconfig that
    # install_dotfiles is about to displace to .bak.
    printf '[user]\n\tname = Prior Person\n\temail = prior@example.invalid\n' \
        > "$TEST_DIR/home/.gitconfig"

    local out
    out=$(_run_install_git_local_config)
    assert_contains "$out" "prior@example.invalid" "the carried-over identity is reported"

    local created="$TEST_DIR/home/.gitconfig_local"
    assert_contains "$(cat "$created")" '^    name = Prior Person$' \
        "install_git_local_config seeds from the machine's existing identity"

    # Never overwritten: a second run must not touch a byte, whatever is in it.
    echo "hand edited" > "$created"
    out=$(_run_install_git_local_config)
    assert_contains "$out" "already exists" "a second run reports and returns"
    assert_equals "hand edited" "$(cat "$created")" \
        "install_git_local_config never overwrites an existing local file"

    # A dangling symlink is still the user's file, not an absence.
    rm "$created"
    ln -s "$TEST_DIR/nowhere" "$created"
    _run_install_git_local_config >/dev/null
    assert_equals "$TEST_DIR/nowhere" "$(readlink "$created")" \
        "a symlinked local file is left alone too"

    teardown
}
