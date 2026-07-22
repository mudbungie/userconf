#!/bin/bash
#
# orb_profile's filename tags: NN_name[.tag][.tag].sh is sourced only if every
# tag holds in the shell that is running right now.
#

# A throwaway shell_config tree whose files each record that they ran.
_tag_fixture() {
    mkdir -p "$TEST_DIR/shell_config"
    local f
    for f in 00_shared 10_bash.bash 10_zsh.zsh 20_inter.interactive \
             30_both.bash.interactive 40_typo.nosuchtag; do
        echo "echo ${f%%.*} >> \"$TEST_DIR/loaded\"" > "$TEST_DIR/shell_config/$f.sh"
    done
}

# Source orb_profile against the fixture in a clean bash and report what loaded.
# $1 is extra flags for bash (e.g. -i).
_tag_load() {
    rm -f "$TEST_DIR/loaded"
    env -u ORB_PROFILE_LOADED bash --norc --noprofile $1 -c \
        "ORB_USERCONF_DIR='$TEST_DIR' . '$REPO_ROOT/orb_profile'" >/dev/null 2>&1
    cat "$TEST_DIR/loaded" 2>/dev/null | tr '\n' ' '
}

test_tag_predicates() {
    echo "=== Testing tag predicates ==="
    setup
    _tag_fixture

    local loaded
    loaded=$(_tag_load)
    assert_equals "00_shared 10_bash " "$loaded" \
        "non-interactive bash loads untagged + bash, and nothing else"

    loaded=$(_tag_load -i)
    assert_equals "00_shared 10_bash 20_inter 30_both " "$loaded" \
        "interactive bash adds the interactive-tagged files"

    teardown
}

test_tag_unknown_fails_closed() {
    echo "=== Testing unknown tags ==="
    setup
    _tag_fixture

    local loaded
    loaded=$(_tag_load -i)
    assert_not_contains "$loaded" "40_typo" \
        "an unknown tag never holds, so a typo fails closed"
    assert_not_contains "$loaded" "10_zsh" \
        "zsh-tagged files do not load in bash"

    teardown
}

test_tag_load_order() {
    echo "=== Testing that tags do not disturb load order ==="
    setup
    _tag_fixture

    local loaded
    loaded=$(_tag_load -i)
    # Numeric prefix order, regardless of which tags each file carries.
    assert_equals "00_shared 10_bash 20_inter 30_both " "$loaded" \
        "files load in numeric-prefix order"

    teardown
}

test_orb_profile_leaves_no_helpers() {
    echo "=== Testing orb_profile cleans up after itself ==="
    setup
    _tag_fixture

    local result
    result=$(env -u ORB_PROFILE_LOADED bash --norc --noprofile -c "
        ORB_USERCONF_DIR='$TEST_DIR' . '$REPO_ROOT/orb_profile'
        declare -F _orb_tag_holds >/dev/null && echo leaked_function
        declare -F _orb_tags_hold >/dev/null && echo leaked_function
        [ -n \"\$_orb_conf\" ] && echo leaked_variable
        [ -n \"\$_orb_rest\" ] && echo leaked_variable
        echo done" 2>&1)

    assert_not_contains "$result" "leaked" \
        "orb_profile unsets its tag helpers and loop variables"

    teardown
}

test_no_shell_name_detection() {
    echo "=== Testing that ORB_SHELL_NAME is gone ==="

    # basename \$SHELL names the *login* shell, so it is wrong in exactly the
    # case that matters: bash typed inside zsh. Tags replaced it; it must not
    # come back anywhere in the tree.
    local hits
    hits=$(grep -rn "ORB_SHELL_NAME" "$REPO_ROOT/orb_profile" \
        "$REPO_ROOT/deploy.sh" "$REPO_ROOT/shell_config" 2>/dev/null || true)
    assert_equals "" "$hits" "ORB_SHELL_NAME is not used anywhere"
}

test_tag_vocabulary_is_closed() {
    echo "=== Testing shell_config filenames use only known tags ==="

    local f base tag bad=""
    for f in "$REPO_ROOT"/shell_config/*.sh; do
        base=${f##*/}
        base=${base%.sh}
        case $base in *.*) ;; *) continue ;; esac
        for tag in $(echo "${base#*.}" | tr '.' ' '); do
            case $tag in
                bash|zsh|interactive) ;;
                *) bad="$bad ${f##*/}:$tag" ;;
            esac
        done
    done
    assert_equals "" "$bad" "every tag in shell_config/ is bash, zsh or interactive"
}

test_bash_only_config_is_tagged() {
    echo "=== Testing bash-only constructs live in .bash files ==="

    # The defect this ball fixes: shopt / PROMPT_COMMAND / bash prompt escapes
    # were being sourced into zsh. Any file carrying them must be tagged bash.
    local f base bad=""
    for f in "$REPO_ROOT"/shell_config/*.sh; do
        base=${f##*/}
        case $base in *.bash.*|*.bash.sh) continue ;; esac
        if grep -qE '^[[:space:]]*(shopt |(export )?PROMPT_COMMAND=)' "$f"; then
            bad="$bad $base"
        fi
    done
    assert_equals "" "$bad" "no untagged file uses shopt or PROMPT_COMMAND"
}

test_zsh_config_under_zsh() {
    echo "=== Testing the zsh half under a real zsh ==="

    if ! command -v zsh >/dev/null 2>&1; then
        skip "zsh half of orb_profile" \
             "zsh is NOT INSTALLED on this machine - zsh support is UNVERIFIED here and ships provisional"
        return 0
    fi

    setup
    _tag_fixture

    rm -f "$TEST_DIR/loaded"
    env -u ORB_PROFILE_LOADED zsh -f -i -c \
        "ORB_USERCONF_DIR='$TEST_DIR' . '$REPO_ROOT/orb_profile'" >/dev/null 2>&1
    local loaded
    loaded=$(tr '\n' ' ' < "$TEST_DIR/loaded" 2>/dev/null)

    assert_contains "$loaded" "10_zsh" "zsh-tagged files load under zsh"
    assert_not_contains "$loaded" "10_bash" "bash-tagged files do not load under zsh"

    # The real config must survive being sourced by zsh.
    local result
    result=$(env -u ORB_PROFILE_LOADED zsh -f -i -c \
        "ORB_USERCONF_DIR='$REPO_ROOT' . '$REPO_ROOT/orb_profile' && echo ok" 2>&1)
    assert_contains "$result" "ok" "the real shell_config sources cleanly under zsh"

    teardown
}
