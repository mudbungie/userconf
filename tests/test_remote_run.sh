#!/bin/bash
#
# bin/bl-remote-run: `make TARGET` on the builder, on the STAGED tree, log
# streamed home, exit = the target's exit (ops bl-1f80). Same sandbox builder
# as test_remote_gate.sh (_gate_machine): its post-receive answers a
# run/<sha>/<target> ref with a log and a status file holding the mode.
#

_run_remote() { # $1=mode (an exit code, or silent) $2=target
    echo "$1" > "$FAKE_ROOT/mode"
    RC=0
    GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@t.local GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@t.local \
        "$REPO_ROOT/bin/bl-remote-run" "$2" > "$TEST_DIR/run.out" 2> "$TEST_DIR/run.err" || RC=$?
}

_run_swept() {
    [ -z "$(git -C "$FAKE_ROOT/git/repo.git" for-each-ref refs/heads/run)" ]
}

test_remote_run_streams_the_log_and_returns_the_targets_exit() {
    echo "=== Testing bl-remote-run: the log comes home, exit is the target's ==="
    setup; _gate_machine
    unset BALLS_TOOLCHAIN     # a run needs no verdict key
    _run_remote 0 test
    assert_equals 0 "$RC" "exit 0 when make test exited 0"
    assert_contains "$(cat "$TEST_DIR/run.out")" "make test: line one" "the builder's log is on stdout"
    assert_true "$(_run_swept; echo $?)" "the run ref was swept"
    teardown
}

test_remote_run_pushes_the_index_tree_under_the_target() {
    echo "=== Testing bl-remote-run: the staged tree travels as run/<sha>/<target> ==="
    setup; _gate_machine
    _run_remote 0 coverage
    tree=$(git write-tree)
    assert_contains "$(cat "$TEST_DIR/run.err")" "tree $tree -> builder:refs/heads/run/" "names the ref"
    out=$(basename "$(ls -d "$FAKE_ROOT"/out/*-coverage)")
    sha=${out%-coverage}
    # The ref is swept but the object stays: what was pushed is the index tree.
    assert_equals "$tree" "$(git -C "$FAKE_ROOT/git/repo.git" rev-parse "$sha^{tree}")" \
        "the pushed commit's tree is the index tree, under out/<sha>-<target>"
    teardown
}

test_remote_run_failing_target_is_its_code() {
    echo "=== Testing bl-remote-run: a failing target's code is the exit ==="
    setup; _gate_machine
    _run_remote 2 check
    assert_equals 2 "$RC" "exit 2 when make check exited 2"
    assert_contains "$(cat "$TEST_DIR/run.err")" "exited 2" "says so"
    teardown
}

test_remote_run_silent_builder_is_124() {
    echo "=== Testing bl-remote-run: no status within the deadline is exit 124 ==="
    setup; _gate_machine
    _run_remote silent test
    assert_equals 124 "$RC" "exit 124 on deadline"
    assert_true "$(_run_swept; echo $?)" "the ref is swept even then"
    teardown
}

test_remote_run_needs_a_target() {
    echo "=== Testing bl-remote-run: no target is usage, nothing pushed ==="
    setup; _gate_machine
    RC=0; "$REPO_ROOT/bin/bl-remote-run" 2> "$TEST_DIR/run.err" || RC=$?
    assert_equals 2 "$RC" "usage exit"
    assert_true "$([ ! -e "$SSH_LOG" ]; echo $?)" "no ssh call was made"
    teardown
}

test_remote_run_brings_the_outputs_home() {
    echo "=== Testing bl-remote-run: what the target left in dist/ lands in .remote/<target>/ ==="
    setup; _gate_machine
    mkdir -p "$FAKE_ROOT/dist-src/sub" && echo apk > "$FAKE_ROOT/dist-src/sub/app.apk"
    _run_remote 0 apk
    assert_equals 0 "$RC" "exit is still the target's"
    assert_equals apk "$(cat .remote/apk/sub/app.apk)" "the output is home, tree intact"
    assert_contains "$(cat "$TEST_DIR/run.err")" "outputs in $PWD/.remote/apk" "names where"
    assert_true "$(git check-ignore -q .remote/apk/sub/app.apk; echo $?)" ".remote/ ignores itself"
    teardown
}

test_remote_run_without_outputs_clears_the_stale_ones() {
    echo "=== Testing bl-remote-run: a run that writes no dist/ leaves no .remote/<target>/ ==="
    setup; _gate_machine
    mkdir -p .remote/apk && echo old > .remote/apk/app.apk
    _run_remote 1 apk
    assert_equals 1 "$RC" "exit is the target's"
    assert_true "$([ ! -e .remote/apk ]; echo $?)" "the previous run's output is gone"
    assert_true "$(grep -q 'outputs in' "$TEST_DIR/run.err"; [ $? -ne 0 ]; echo $?)" "claims no outputs"
    teardown
}

test_remote_names_are_one_script() {
    echo "=== Testing bin/: bl-remote-gate and bl-remote-run are links to bl-remote ==="
    assert_equals bl-remote "$(readlink "$REPO_ROOT/bin/bl-remote-gate")" "gate is a link"
    assert_equals bl-remote "$(readlink "$REPO_ROOT/bin/bl-remote-run")" "run is a link"
}
