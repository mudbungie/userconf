#!/bin/bash
#
# shell_config/25_colors.interactive.sh: the ls/grep color setup that Ubuntu's
# stock ~/.bashrc used to provide and that deploy.sh displaces.
#

_colors_file() { echo "$REPO_ROOT/shell_config/25_colors.interactive.sh"; }

# Source the slot in a clean bash with a stubbed PATH and report what it did.
# $1 is a directory to put in front of PATH (to supply or withhold dircolors).
_colors_load() {
    env -i HOME="$TEST_DIR" PATH="$1:/usr/bin:/bin" bash --norc --noprofile -c "
        shopt -s expand_aliases
        . '$(_colors_file)'
        echo \"LS_COLORS=\$LS_COLORS\"
        echo \"CLICOLOR=\$CLICOLOR\"
        alias ls grep 2>/dev/null" 2>&1
}

test_colors_gnu_branch() {
    echo "=== Testing the GNU (dircolors) branch ==="
    setup

    mkdir -p "$TEST_DIR/bin"
    # Real dircolors -b quotes the value; the ';' inside it would otherwise be
    # read as a command separator by the eval, so the stub quotes it too.
    printf "#!/bin/sh\necho \"LS_COLORS='di=01;34:'; export LS_COLORS\"\n" \
        > "$TEST_DIR/bin/dircolors"
    chmod +x "$TEST_DIR/bin/dircolors"

    local out
    out=$(_colors_load "$TEST_DIR/bin")
    assert_contains "$out" "LS_COLORS=di=01;34" \
        "dircolors output is eval'd, so LS_COLORS is populated"
    assert_contains "$out" "ls --color=auto" \
        "ls is aliased to --color=auto where GNU ls is what we have"
    assert_contains "$out" "grep --color=auto" "grep is aliased to --color=auto"

    teardown
}

test_colors_bsd_branch() {
    echo "=== Testing the BSD/macOS (no dircolors) branch ==="
    setup

    # An empty stub dir does not hide the system dircolors, so the whole PATH
    # has to be a directory that has none - which means bash itself has to be
    # named by absolute path, since PATH can no longer find it.
    mkdir -p "$TEST_DIR/empty"
    local out
    out=$(env -i HOME="$TEST_DIR" PATH="$TEST_DIR/empty" \
        "$(command -v bash)" --norc --noprofile -c "
        shopt -s expand_aliases
        . '$(_colors_file)'
        echo \"CLICOLOR=\$CLICOLOR\"
        alias ls" 2>&1)

    assert_contains "$out" "CLICOLOR=1" \
        "without dircolors, CLICOLOR is what turns BSD ls color on"
    assert_contains "$out" "ls -G" "and ls takes -G rather than --color=auto"

    teardown
}

test_colors_honors_user_dircolors() {
    echo "=== Testing that ~/.dircolors wins when it exists ==="
    setup

    mkdir -p "$TEST_DIR/bin"
    # Echoes back which database it was handed, so the test can tell them apart.
    printf '#!/bin/sh\necho "LS_COLORS=%s; export LS_COLORS"\n' "'from:\${2:-default}'" \
        > "$TEST_DIR/bin/dircolors"
    chmod +x "$TEST_DIR/bin/dircolors"
    echo "DIR 01;34" > "$TEST_DIR/.dircolors"

    local out
    out=$(_colors_load "$TEST_DIR/bin")
    assert_contains "$out" "from:$TEST_DIR/.dircolors" \
        "a readable ~/.dircolors is passed to dircolors -b"

    teardown
}

test_colors_is_interactive_only() {
    echo "=== Testing the slot does not load in scripts ==="

    # `ls --color=auto` is safe in a pipe, but the dircolors fork is pure cost
    # in a non-interactive shell and the aliases are not wanted there at all.
    local base
    base=$(basename "$(_colors_file)")
    assert_contains "$base" "interactive" \
        "the filename carries the interactive tag"

    # And no shell tag: the file must load under bash and zsh both.
    assert_not_contains "$base" ".bash." "the slot is not bash-tagged"
    assert_not_contains "$base" ".zsh." "the slot is not zsh-tagged"
}
