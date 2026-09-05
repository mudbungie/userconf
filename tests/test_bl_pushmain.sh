#!/bin/bash
#
# bin/bl-pushmain: the close.post plugin that pushes the code branch after a
# delivery. What is under test is its noise, not git's: a repo with no origin
# has nothing to push and must say nothing, while a push that genuinely fails
# must still be loud enough to notice.
#

# Run the plugin as balls would: `close post` with the §7 envelope on stdin.
# Stdout is captured; stderr lands in $TEST_DIR/push.err.
run_pushmain() { # $1=repo
    printf '{"binding":{"invocation_path":"%s"}}' "$1" \
        | "$REPO_ROOT/bin/bl-pushmain" close post 2>"$TEST_DIR/push.err"
}

# A repo on branch main with one commit, at $TEST_DIR/repo.
_pushmain_repo() {
    mkdir -p "$TEST_DIR/repo"
    cd "$TEST_DIR/repo" || return 1
    git init -q -b main
    echo seed > seed.txt
    git add seed.txt
    git -c user.email=t@t.local -c user.name=T commit -qm seed
}

test_pushmain_says_nothing_without_an_origin() {
    echo "=== Testing bl-pushmain is silent on a repo with no origin ==="
    setup
    _pushmain_repo

    local out rc=0
    out=$(run_pushmain "$TEST_DIR/repo") || rc=$?

    assert_true $rc "no remote is not a failure"
    assert_equals "" "$out" "nothing on stdout"
    assert_equals "" "$(cat "$TEST_DIR/push.err")" \
        "nothing on stderr either - there is no push to report on"

    teardown
}

test_pushmain_warns_when_the_push_is_rejected() {
    echo "=== Testing bl-pushmain warns loudly on a real push failure ==="
    setup
    _pushmain_repo
    # An origin that resolves to nothing: the push is attempted and fails,
    # which is the case the warning exists for.
    git remote add origin "$TEST_DIR/no-such-repo"

    local rc=0
    run_pushmain "$TEST_DIR/repo" >/dev/null || rc=$?
    local err
    err=$(cat "$TEST_DIR/push.err")

    assert_true $rc "a failed push still never fails the close"
    assert_contains "$err" "WARNING could not push main" \
        "a broken origin is reported, not swallowed"

    teardown
}

test_pushmain_pushes_to_a_real_origin() {
    echo "=== Testing bl-pushmain pushes main when it can ==="
    setup
    git init -q --bare "$TEST_DIR/origin.git"
    _pushmain_repo
    git remote add origin "$TEST_DIR/origin.git"

    local rc=0
    run_pushmain "$TEST_DIR/repo" >/dev/null || rc=$?
    local err
    err=$(cat "$TEST_DIR/push.err")

    assert_true $rc "a clean push exits 0"
    assert_contains "$err" "pushed main -> origin" "and reports what it did"
    assert_equals "$(git -C "$TEST_DIR/repo" rev-parse main)" \
        "$(git -C "$TEST_DIR/origin.git" rev-parse main)" \
        "origin/main really moved to the local main"

    teardown
}

test_pushmain_protocol_handshake() {
    echo "=== Testing bl-pushmain protocol handshake ==="
    setup
    local out
    out=$("$REPO_ROOT/bin/bl-pushmain" protocol)
    assert_contains "$out" '"protocol"' "handshake speaks the protocol"
    assert_contains "$out" '"close"' "handshake covers close"
    teardown
}

test_pushmain_abstains_off_close_post() {
    echo "=== Testing bl-pushmain abstains outside close.post ==="
    setup
    local rc=0
    printf '{}' | "$REPO_ROOT/bin/bl-pushmain" close pre >/dev/null 2>&1 || rc=$?
    assert_true $rc "there is nothing to push before the delivery lands"
    teardown
}
