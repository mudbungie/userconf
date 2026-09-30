#!/bin/bash
#
# bin/bl-gate: the shared pre-commit gate (ops bl-1f80). Every tool it calls is
# faked on PATH and writes what it saw into the sandbox, so the tests read the
# protocol back: which toolchain string was exported, whether leak-scan ran,
# and that a cache hit never reaches the builder while a miss always does.
#

_gate_sandbox() { # a repo with a staged file, fake tools, mode files
    mkdir -p "$TEST_DIR/bin" "$TEST_DIR/repo"
    export GATE_LOG="$TEST_DIR/gate.log"
    cat > "$TEST_DIR/bin/bl-speculate" <<EOF
#!/bin/bash
echo "bl-speculate \$1 toolchain=\${BALLS_TOOLCHAIN-UNSET}" >> "$GATE_LOG"
[ "\$1" = check ] && [ "\$(cat "$TEST_DIR/check-mode")" = hit ] && exit 0
exit 3
EOF
    cat > "$TEST_DIR/bin/bl-remote-gate" <<EOF
#!/bin/bash
echo "bl-remote-gate toolchain=\${BALLS_TOOLCHAIN-UNSET}" >> "$GATE_LOG"
exit "\$(cat "$TEST_DIR/remote-exit")"
EOF
    cat > "$TEST_DIR/bin/rustc" <<EOF
#!/bin/bash
echo "rustc 0.0.0 (fake)"
EOF
    chmod +x "$TEST_DIR/bin/"*
    echo miss > "$TEST_DIR/check-mode"; echo 0 > "$TEST_DIR/remote-exit"
    PATH="$TEST_DIR/bin:$PATH"
    cd "$TEST_DIR/repo" || return 1
    git init -q -b main
    echo staged > staged.txt && git add staged.txt
}

_gate() { RC=0; "$REPO_ROOT/bin/bl-gate" > "$TEST_DIR/out" 2> "$TEST_DIR/err" || RC=$?; }

test_gate_miss_goes_to_the_builder_with_rustc_as_the_toolchain() {
    echo "=== Testing bl-gate: a miss exports rustc -V and execs bl-remote-gate ==="
    setup; _gate_sandbox
    _gate
    assert_equals 0 "$RC" "the builder's exit is the gate's exit"
    assert_contains "$(cat "$GATE_LOG")" "bl-speculate check toolchain=rustc 0.0.0 (fake)" "check saw rustc -V"
    assert_contains "$(cat "$GATE_LOG")" "bl-remote-gate toolchain=rustc 0.0.0 (fake)" "the builder client inherited it"
    teardown
}

test_gate_hit_never_reaches_the_builder() {
    echo "=== Testing bl-gate: a verdict cache hit is exit 0 with no remote call ==="
    setup; _gate_sandbox
    echo hit > "$TEST_DIR/check-mode"
    _gate
    assert_equals 0 "$RC" "exit 0"
    assert_not_contains "$(cat "$GATE_LOG")" "bl-remote-gate" "bl-remote-gate was not called"
    assert_contains "$(cat "$TEST_DIR/err")" "cache hit" "says so"
    teardown
}

test_gate_builder_verdict_is_the_gates_exit() {
    echo "=== Testing bl-gate: 1 and 75 from the builder pass straight through ==="
    setup; _gate_sandbox
    echo 75 > "$TEST_DIR/remote-exit"; _gate
    assert_equals 75 "$RC" "75 = no verdict"
    echo 1 > "$TEST_DIR/remote-exit"; _gate
    assert_equals 1 "$RC" "1 = the builder failed the tree"
    teardown
}

test_gate_scripts_toolchain_outranks_rustc() {
    echo "=== Testing bl-gate: an executable scripts/toolchain names the toolchain ==="
    setup; _gate_sandbox
    mkdir -p scripts && printf '#!/bin/sh\necho "openjdk 17 (fake)"\n' > scripts/toolchain && chmod +x scripts/toolchain
    _gate
    assert_contains "$(cat "$GATE_LOG")" "toolchain=openjdk 17 (fake)" "the tree's own string was exported"
    assert_not_contains "$(cat "$GATE_LOG")" "rustc" "rustc -V was not consulted"
    teardown
}

test_gate_leak_scan_runs_only_when_the_makefile_has_it() {
    echo "=== Testing bl-gate: make leak-scan runs locally iff the target exists ==="
    setup; _gate_sandbox
    _gate
    assert_not_contains "$(cat "$TEST_DIR/err")" "leak-scan" "no Makefile: no scan"
    printf 'leak-scan:\n\t@echo scanned > "%s/scanned"\n' "$TEST_DIR" > Makefile
    _gate
    assert_true "$([ -f "$TEST_DIR/scanned" ]; echo $?)" "with the target: it ran, here"
    teardown
}

test_gate_without_a_toolchain_refuses() {
    echo "=== Testing bl-gate: no scripts/toolchain and no rustc is a hard refusal ==="
    setup; _gate_sandbox
    rm "$TEST_DIR/bin/rustc"
    PATH="$TEST_DIR/bin:/usr/bin:/bin" _gate   # no ~/.cargo/bin: no rustc anywhere
    assert_equals 1 "$RC" "exit 1"
    assert_not_contains "$(cat "$GATE_LOG" 2>/dev/null)" "bl-remote-gate" "nothing was submitted"
    teardown
}
