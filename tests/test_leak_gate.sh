#!/bin/bash
#
# bin/bl-leak-gate: the machine-global balls task-store gate, and the
# install_local_bins deploy step that puts it on PATH.
#

# Run the gate as balls would: <op> <phase> with the §7 payload on stdin.
run_gate() {
    local op="$1" phase="$2" payload="$3"
    printf '%s' "$payload" | "$REPO_ROOT/bin/bl-leak-gate" "$op" "$phase" 2>"$TEST_DIR/gate.err"
}

payload() { # $1=repo $2=store
    printf '{"binding":{"invocation_path":"%s","store":"%s"}}' "$1" "$2"
}

test_leak_gate_protocol_handshake() {
    echo "=== Testing bl-leak-gate protocol handshake ==="
    setup
    local out
    out=$("$REPO_ROOT/bin/bl-leak-gate" protocol)
    assert_contains "$out" '"protocol"' "handshake speaks the protocol"
    assert_contains "$out" '"close"' "handshake covers the publishing ops"
    teardown
}

test_leak_gate_passes_a_project_with_no_scanner() {
    echo "=== Testing bl-leak-gate passes without a scanner (not opted in) ==="
    setup
    mkdir -p "$TEST_DIR/repo" "$TEST_DIR/store"
    local rc=0
    run_gate close post "$(payload "$TEST_DIR/repo" "$TEST_DIR/store")" || rc=$?
    assert_true $rc "no scripts/leak-scan.sh means no policy, so the op passes"
    teardown
}

test_leak_gate_abstains_off_post() {
    echo "=== Testing bl-leak-gate abstains on pre ==="
    setup
    local rc=0
    run_gate close pre '{}' || rc=$?
    assert_true $rc "only post can see what the op wrote"
    teardown
}

test_leak_gate_runs_the_scanner_in_the_store() {
    echo "=== Testing bl-leak-gate verdicts follow the project's scanner ==="
    setup
    mkdir -p "$TEST_DIR/repo/scripts" "$TEST_DIR/store"
    # A stand-in scanner: fails iff the tree it is RUN IN contains "SECRET".
    cat > "$TEST_DIR/repo/scripts/leak-scan.sh" <<'SCANNER'
#!/bin/sh
! grep -r SECRET . >/dev/null 2>&1
SCANNER
    chmod +x "$TEST_DIR/repo/scripts/leak-scan.sh"
    echo "clean ball body" > "$TEST_DIR/store/task.md"
    local rc=0
    run_gate close post "$(payload "$TEST_DIR/repo" "$TEST_DIR/store")" || rc=$?
    assert_true $rc "a clean store passes the opted-in gate"
    echo "a SECRET value" > "$TEST_DIR/store/task.md"
    rc=0
    run_gate close post "$(payload "$TEST_DIR/repo" "$TEST_DIR/store")" || rc=$?
    assert_false $rc "a finding refuses the op"
    assert_contains "$(cat "$TEST_DIR/gate.err")" "REFUSED" "the refusal says why"
    teardown
}

test_leak_gate_fails_closed_when_opted_in_store_is_unreadable() {
    echo "=== Testing bl-leak-gate fails closed for an opted-in project ==="
    setup
    mkdir -p "$TEST_DIR/repo/scripts"
    printf '#!/bin/sh\nexit 0\n' > "$TEST_DIR/repo/scripts/leak-scan.sh"
    chmod +x "$TEST_DIR/repo/scripts/leak-scan.sh"
    local rc=0
    run_gate close post "$(payload "$TEST_DIR/repo" "$TEST_DIR/missing")" || rc=$?
    assert_false $rc "a scanner with no readable store refuses rather than shrugs"
    teardown
}

test_leak_gate_fails_open_loudly_on_an_unreadable_payload() {
    echo "=== Testing bl-leak-gate degrades to a nag on a broken payload ==="
    setup
    local rc=0
    run_gate close post 'not json at all' || rc=$?
    assert_true $rc "an unreadable payload must not brick every bl op on the box"
    assert_contains "$(cat "$TEST_DIR/gate.err")" "UNSCANNED" "but it nags loudly"
    teardown
}

test_install_local_bins_symlinks_executables() {
    echo "=== Testing install_local_bins converges the ~/.local/bin links ==="
    setup
    mkdir -p "$TEST_DIR/home/.local/bin"
    # Exercise the real deploy.sh function against a sandbox HOME.
    (
        cd "$REPO_ROOT"
        # shellcheck disable=SC1091
        source /dev/stdin <<< "$(sed -n '/^function install_local_bins/,/^}/p' deploy.sh)"
        HOME="$TEST_DIR/home" install_local_bins
    )
    local rc=0
    [[ -L "$TEST_DIR/home/.local/bin/bl-leak-gate" ]] || rc=$?
    assert_true $rc "the gate is linked into ~/.local/bin"
    assert_equals "$REPO_ROOT/bin/bl-leak-gate" \
        "$(readlink "$TEST_DIR/home/.local/bin/bl-leak-gate")" \
        "the link aims at the repo copy (hard-coded clone path, like dotfiles)"
    teardown
}
