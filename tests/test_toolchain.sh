#!/bin/bash
#
# D4 toolchain policy: the base install set, mise in place of nvm/Poetry, and
# the tool dependencies of tracked shell functions.
#
# Nothing here touches the real $HOME or the network: package managers and
# curl are faked into a temp PATH, and $HOME is repointed at the sandbox.
#

# The rule from D4, applied: bootstrap/recovery tools, plus tools a tracked file
# actually calls. Anything else is a per-machine preference (D3).
BASE_PACKAGES="git curl vim jq python3"

_base_package_line() {
    sed -n 's/^ *local programs="\(.*\)"$/\1/p' "$REPO_ROOT/deploy.sh"
}

test_base_package_set() {
    echo "=== Testing the base package set ==="

    assert_equals "$BASE_PACKAGES" "$(_base_package_line)" \
        "deploy.sh installs exactly the D4 base set"

    # Each exclusion is a rule outcome, not a taste: if no tracked file calls
    # it and you can still clone and repair the repo without it, it is out.
    # Comment lines do not count as a call - prose may still name nvm.
    local tool hits
    for tool in wget ripgrep rg fzf direnv tmux poetry nvm sponge; do
        hits=$(grep -rnwI -- "$tool" "$REPO_ROOT/deploy.sh" "$REPO_ROOT/orb_profile" \
                    "$REPO_ROOT/shell_config" "$REPO_ROOT/dotfiles" 2>/dev/null \
               | grep -v ':[0-9]*:[[:space:]]*[#"]') || true
        assert_equals "" "$hits" "no tracked config calls $tool (so it stays out of the base set)"
    done
}

test_install_not_packages_is_gone() {
    echo "=== Testing that install_not_packages is deleted ==="

    assert_not_contains "$(cat "$REPO_ROOT/deploy.sh")" "install_not_packages" \
        "install_not_packages (curl-piped nvm v0.39.2 + Poetry) is deleted, not wired"
    assert_not_contains "$(cat "$REPO_ROOT/deploy.sh")" "python-poetry" \
        "deploy.sh no longer installs Poetry - mise covers python"
}

test_install_mise_is_idempotent() {
    echo "=== Testing install_mise ==="
    setup
    source_deploy_functions

    # PATH is replaced outright, not prepended: a machine that really has mise
    # installed must not leak into the "absent" cases below.
    local bin="$TEST_DIR/bin"
    mkdir -p "$bin"
    ln -s "$(command -v sh)" "$bin/sh"
    ln -s "$(command -v mktemp)" "$bin/mktemp"
    ln -s "$(command -v rm)" "$bin/rm"

    # A machine that already has mise (brew, or a previous deploy) is left
    # alone, and in particular is not re-curled.
    printf '#!/bin/sh\nexit 0\n' > "$bin/mise"
    chmod +x "$bin/mise"
    local output
    output=$( PATH="$bin"; install_mise 2>&1 )
    assert_contains "$output" "already installed" "install_mise is a no-op when mise is present"
    assert_not_contains "$output" "Installing mise" "install_mise does not reinstall over an existing mise"

    # A machine without it: the vendor installer runs, and nothing else does.
    # curl is faked to emit a script, so no network is touched.
    rm "$bin/mise"
    printf '#!/bin/sh\necho "echo FAKE_MISE_INSTALLER_RAN"\n' > "$bin/curl"
    chmod +x "$bin/curl"
    output=$( PATH="$bin"; install_mise 2>&1 )
    assert_contains "$output" "FAKE_MISE_INSTALLER_RAN" "install_mise runs the vendor installer when mise is absent"

    # No network and no installer: report, do not abort the deploy.
    printf '#!/bin/sh\nexit 7\n' > "$bin/curl"
    local result
    ( PATH="$bin"; install_mise ) >/dev/null 2>&1 && result=0 || result=$?
    assert_equals "1" "$result" "install_mise returns 1 when the download fails"

    teardown
}

# Source the bash slot-50 file in a clean bash whose entire PATH is $1, and
# echo what it printed plus a marker of what the eval defined. An absolute
# $BASH is used because the sandbox PATH cannot be trusted to contain a shell.
_load_mise_slot() {
    env -i HOME="$TEST_DIR" PATH="$1" "$BASH" --norc --noprofile -c \
        ". '$REPO_ROOT/shell_config/50_mise.bash.interactive.sh' && echo LOADED_OK; echo \"MISE_MARKER=\$MISE_MARKER\"" 2>&1
}

test_mise_slot_activation() {
    echo "=== Testing shell_config/50_mise.*.interactive.sh ==="
    setup

    local bin="$TEST_DIR/bin"
    mkdir -p "$bin"

    # No mise on the machine: silent no-op, and the file still returns success
    # so it cannot break a shell that merely has not installed it.
    local output
    output=$(_load_mise_slot "$bin")
    assert_contains "$output" "LOADED_OK" "the mise slot succeeds on a machine without mise"
    assert_equals "MISE_MARKER=" "$(echo "$output" | grep MISE_MARKER=)" \
        "the mise slot activates nothing when mise is absent"

    # mise present: its activation output is eval'd, once, into the shell.
    printf '#!/bin/sh\ntest "$1" = activate || exit 1\necho "MISE_MARKER=$2"\n' > "$bin/mise"
    chmod +x "$bin/mise"
    output=$(_load_mise_slot "$bin")
    assert_equals "MISE_MARKER=bash" "$(echo "$output" | grep MISE_MARKER=)" \
        "the bash slot evals \`mise activate bash\`"

    # The zsh half must ask for zsh activation, not bash's.
    assert_contains "$(cat "$REPO_ROOT/shell_config/50_mise.zsh.interactive.sh")" \
        'mise activate zsh' "the zsh slot evals \`mise activate zsh\`"

    # No nvm left anywhere in the loaded config.
    local nvm_files
    nvm_files=$(ls "$REPO_ROOT"/shell_config/*nvm* 2>/dev/null) || true
    assert_equals "" "$nvm_files" "no nvm file survives in shell_config"

    teardown
}

test_real_mise_activation() {
    echo "=== Testing activation against a real mise ==="

    if ! command -v mise >/dev/null 2>&1; then
        skip "mise activation" \
             "mise is NOT INSTALLED on this machine - the generated activation snippet is UNVERIFIED here; deploy.sh installs it, this suite only proves the slot is a no-op without it"
        return 0
    fi

    local output
    output=$(mise activate bash 2>&1) || output="error"
    assert_not_contains "$output" "error" "\`mise activate bash\` produces an activation snippet"

    output=$(env -u ORB_PROFILE_LOADED bash --norc --noprofile -i -c \
        ". '$REPO_ROOT/shell_config/50_mise.bash.interactive.sh' && echo ok" 2>&1)
    assert_contains "$output" "ok" "the real mise activation sources cleanly"
}

test_rectify_json_needs_only_jq() {
    echo "=== Testing rectify_json ==="
    setup

    if ! command -v jq >/dev/null 2>&1; then
        skip "rectify_json" "jq is NOT INSTALLED on this machine"
        teardown
        return 0
    fi

    printf '{"b":2,"a":1}' > "$TEST_DIR/doc.json"
    rectify_json "$TEST_DIR/doc.json"
    assert_contains "$(cat "$TEST_DIR/doc.json")" '"b": 2' "rectify_json reformats in place without sponge"

    # Garbage in: the original file must survive untouched, and no temp file
    # may be left behind.
    printf 'not json' > "$TEST_DIR/bad.json"
    local result
    rectify_json "$TEST_DIR/bad.json" >/dev/null 2>&1 && result=0 || result=$?
    assert_false $result "rectify_json fails on unparseable input"
    assert_equals "not json" "$(cat "$TEST_DIR/bad.json")" "rectify_json leaves bad input untouched"
    assert_equals "" "$(ls "$TEST_DIR"/*.rectify.* 2>/dev/null)" "rectify_json leaves no temp file behind"

    teardown
}
