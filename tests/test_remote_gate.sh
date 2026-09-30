#!/bin/bash
#
# bin/bl-remote-gate: the noodlezoo builder client (ops bl-9e5b). Everything
# remote is faked locally: `ssh` runs its command here with /tank/build
# rewritten into the sandbox, the bare repo's post-receive plays the builder
# (pass / fail / tamper / silent, chosen by a mode file), verdicts are signed
# with a throwaway ed25519 key that the sandbox's allowed_signers trusts, and
# `bl-speculate` is a stub with 0.5.13's contract (BALLS_TOOLCHAIN required,
# check 0/3, import by <tree>-<gate>.toml name). What is under test is the
# protocol: what gets imported, what gets refused, and the three exit codes.
#

# A sandbox builder + a repo with a STAGED change, so the tree that must travel
# is the index tree, not HEAD's. Leaves the shell inside the repo.
_gate_machine() {
    export FAKE_ROOT="$TEST_DIR/tank/build" FAKE_STORE="$TEST_DIR/store"
    mkdir -p "$FAKE_ROOT" "$FAKE_STORE" "$TEST_DIR/bin" "$TEST_DIR/config/balls" \
             "$TEST_DIR/template/hooks"
    ssh-keygen -q -t ed25519 -N "" -f "$TEST_DIR/key"
    echo "noodlezoo $(cut -d' ' -f1,2 "$TEST_DIR/key.pub")" \
        > "$TEST_DIR/config/balls/allowed_signers"
    export XDG_CONFIG_HOME="$TEST_DIR/config" GIT_TEMPLATE_DIR="$TEST_DIR/template"
    export BALLS_TOOLCHAIN="rustc 0.0.0 (test)" SSH_LOG="$TEST_DIR/ssh.log"

    cat > "$TEST_DIR/bin/ssh" <<EOF
#!/bin/bash
while [[ \${1:-} == -* ]]; do case \$1 in -o|-p|-i|-F) shift 2 ;; *) shift ;; esac; done
shift   # the host
cmd="\$*"; echo "\$cmd" >> "$SSH_LOG"
cmd="\${cmd//\/tank\/build/$FAKE_ROOT}"; cmd="\${cmd//timeout 3600/timeout 3}"
exec bash -c "\$cmd"
EOF
    cat > "$TEST_DIR/bin/bl-speculate" <<EOF
#!/bin/bash
[ -n "\${BALLS_TOOLCHAIN:-}" ] || { echo "BALLS_TOOLCHAIN is unset" >&2; exit 1; }
case \$1 in
  check) f="$FAKE_STORE/\$(git write-tree)-g.toml"
         [ -f "\$f" ] && grep -qx 'pass = true' "\$f" && exit 0; exit 3 ;;
  import) shift; for f; do [[ \$(basename "\$f") =~ ^[0-9a-f]{40}-g\.toml$ ]] || exit 1
                           cp "\$f" "$FAKE_STORE/"; done ;;
esac
EOF
    # The builder: one verdict per speculation ref, shaped by \$FAKE_ROOT/mode;
    # a run/<sha>/<target> ref gets a log and a status = exit code (mode is
    # the code; `silent` writes neither).
    cat > "$TEST_DIR/template/hooks/post-receive" <<EOF
#!/bin/bash
mode=\$(cat "$FAKE_ROOT/mode")
while read -r _o new ref; do
  if [[ \$ref == refs/heads/run/* ]]; then
    target=\${ref##*/}; out="$FAKE_ROOT/out/\$new-\$target"; mkdir -p "\$out"
    [ "\$mode" = silent ] && continue
    printf 'make %s: line one\\nline two\\n' "\$target" > "\$out/log"
    echo "\$mode" > "\$out/status"; continue
  fi
  [[ \$ref == refs/heads/speculation/* ]] || continue
  out="$FAKE_ROOT/out/\$new"; mkdir -p "\$out"
  [ "\$mode" = silent ] && continue
  tree=\$(git rev-parse "\$new^{tree}"); v="\$out/\$tree-g.toml"
  [ "\$mode" = fail ] && echo 'pass = false' > "\$v" || echo 'pass = true' > "\$v"
  ssh-keygen -q -Y sign -f "$TEST_DIR/key" -n balls-verdict "\$v"
  [ "\$mode" = tamper ] && echo 'pass = false' > "\$v"   # body no longer matches the signature
  [ "\$mode" = fail ] && echo fail > "\$out/status" || echo pass > "\$out/status"
done
EOF
    chmod +x "$TEST_DIR/bin/"* "$TEST_DIR/template/hooks/post-receive"
    PATH="$TEST_DIR/bin:$PATH"

    mkdir -p "$TEST_DIR/repo" && cd "$TEST_DIR/repo" || return 1
    git init -q -b main
    git -c user.email=t@t.local -c user.name=T commit -q --allow-empty -m seed
    echo staged > staged.txt && git add staged.txt
}

_run_gate() { # $1=mode -> rc in $RC, stderr in $TEST_DIR/gate.err
    echo "$1" > "$FAKE_ROOT/mode"
    RC=0
    GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@t.local GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@t.local \
        "$REPO_ROOT/bin/bl-remote-gate" 2> "$TEST_DIR/gate.err" || RC=$?
}

_swept() { # no speculation ref survives a run
    [ -z "$(git -C "$FAKE_ROOT/git/repo.git" for-each-ref refs/heads/speculation)" ]
}

test_remote_gate_pass_imports_the_index_tree_verdict() {
    echo "=== Testing bl-remote-gate: a verified PASS is imported and hits ==="
    setup; _gate_machine
    _run_gate pass
    assert_equals 0 "$RC" "exit 0 on a verified pass"
    assert_true "$([ -f "$FAKE_STORE/$(git write-tree)-g.toml" ]; echo $?)" \
        "the verdict for the INDEX tree is in the store"
    assert_true "$(_swept; echo $?)" "the speculation ref was swept"
    teardown
}

test_remote_gate_fail_is_exit_one() {
    echo "=== Testing bl-remote-gate: a verified FAIL is exit 1 ==="
    setup; _gate_machine
    _run_gate fail
    assert_equals 1 "$RC" "exit 1 when the builder failed the tree"
    assert_contains "$(cat "$TEST_DIR/gate.err")" "FAILED tree" "says so"
    teardown
}

test_remote_gate_tampered_verdict_is_discarded() {
    echo "=== Testing bl-remote-gate: a verdict whose signature fails is never imported ==="
    setup; _gate_machine
    _run_gate tamper
    assert_equals 75 "$RC" "exit 75, not a verdict either way"
    assert_equals "" "$(ls "$FAKE_STORE")" "nothing imported"
    assert_contains "$(cat "$TEST_DIR/gate.err")" "DISCARDING" "the discard is loud"
    teardown
}

test_remote_gate_silent_builder_is_75() {
    echo "=== Testing bl-remote-gate: no status within the deadline is exit 75 ==="
    setup; _gate_machine
    _run_gate silent
    assert_equals 75 "$RC" "exit 75 on deadline"
    assert_true "$(_swept; echo $?)" "the ref is swept even then"
    teardown
}

test_remote_gate_requires_the_gates_toolchain() {
    echo "=== Testing bl-remote-gate: without BALLS_TOOLCHAIN it does nothing and exits 75 ==="
    setup; _gate_machine
    unset BALLS_TOOLCHAIN
    _run_gate pass
    assert_equals 75 "$RC" "exit 75"
    assert_true "$([ ! -e "$SSH_LOG" ]; echo $?)" "no ssh call was made"
    assert_contains "$(cat "$TEST_DIR/gate.err")" "BALLS_TOOLCHAIN" "names the variable"
    teardown
}

test_deploy_links_allowed_signers() {
    echo "=== Testing deploy.sh: allowed_signers is linked under XDG_CONFIG_HOME/balls ==="
    setup
    source_deploy_functions
    XDG_CONFIG_HOME="$TEST_DIR/xdg"
    (cd "$REPO_ROOT" && install_balls_signers > /dev/null)
    assert_equals "$REPO_ROOT/balls/allowed_signers" \
        "$(readlink "$TEST_DIR/xdg/balls/allowed_signers")" "link points into the repo"
    (cd "$REPO_ROOT" && install_balls_signers > /dev/null)   # idempotent
    assert_equals "$REPO_ROOT/balls/allowed_signers" \
        "$(readlink "$TEST_DIR/xdg/balls/allowed_signers")" "still one correct link"
    teardown
}
