#!/bin/bash
#
# bin/bl-refresh: the close.post plugin that carries a stale checkout forward
# after bl-delivery moved its branch by plumbing. The close is simulated the way
# bl-delivery lands it: a commit built elsewhere, then `git update-ref` on the
# branch - the checkout on that branch is never told.
#

_rgit() { git -c user.email=t@t.local -c user.name=T "$@"; }

# Run the plugin as balls would. $1=repo, $2=optional extra JSON members.
# Stdout is captured; stderr lands in $TEST_DIR/refresh.err.
run_refresh() {
    printf '{"binding":{"invocation_path":"%s"}%s}' "$1" "${2-}" \
        | "$REPO_ROOT/bin/bl-refresh" close post 2>"$TEST_DIR/refresh.err"
}

# $TEST_DIR/repo on master holding a.txt and b.txt, both "one".
_refresh_repo() {
    mkdir -p "$TEST_DIR/repo"
    cd "$TEST_DIR/repo" || return 1
    git init -q -b master
    echo one > a.txt
    echo one > b.txt
    git add a.txt b.txt
    _rgit commit -qm seed
}

# The close: from a side worktree change a.txt and add c.txt (b.txt stays
# untouched), then move master by plumbing.
_refresh_deliver() {
    local wt="$TEST_DIR/side" old new
    old=$(git -C "$TEST_DIR/repo" rev-parse master)
    git -C "$TEST_DIR/repo" worktree add -q --detach "$wt" master
    echo two > "$wt/a.txt"
    echo new > "$wt/c.txt"
    git -C "$wt" add a.txt c.txt
    _rgit -C "$wt" commit -qm delivery
    new=$(git -C "$wt" rev-parse HEAD)
    git -C "$TEST_DIR/repo" update-ref -m "delivery" refs/heads/master "$new" "$old"
}

_index_is_tip() {
    [ "$(git -C "$TEST_DIR/repo" write-tree)" = \
      "$(git -C "$TEST_DIR/repo" rev-parse 'master^{tree}')" ]
}

test_refresh_carries_a_fresh_close_forward() {
    echo "=== Testing bl-refresh brings a stale checkout to the delivered tip ==="
    setup
    _refresh_repo
    _refresh_deliver

    local out rc=0
    out=$(run_refresh "$TEST_DIR/repo") || rc=$?

    assert_true $rc "a refresh exits 0"
    assert_equals "" "$out" "stdout stays empty"
    assert_equals "two" "$(cat a.txt)" "the changed file is updated"
    assert_equals "new" "$(cat c.txt 2>/dev/null)" "the added file appears"
    assert_equals "" "$(git status --porcelain)" "no phantom staged revert remains"
    assert_contains "$(cat "$TEST_DIR/refresh.err")" "carried" "and it says what it did"
    teardown
}

test_refresh_keeps_a_local_edit_the_close_did_not_touch() {
    echo "=== Testing bl-refresh carries an unrelated local edit forward ==="
    setup
    _refresh_repo
    _refresh_deliver
    echo mine > b.txt

    local rc=0
    run_refresh "$TEST_DIR/repo" >/dev/null || rc=$?

    assert_true $rc "exits 0"
    assert_equals "two" "$(cat a.txt)" "the delivered change lands"
    assert_equals "mine" "$(cat b.txt)" "the local edit survives"
    assert_equals " M b.txt" "$(git status --porcelain)" "and is the only difference"
    teardown
}

test_refresh_refuses_when_a_touched_file_is_edited_locally() {
    echo "=== Testing bl-refresh warns and touches nothing on a conflict ==="
    setup
    _refresh_repo
    _refresh_deliver
    echo mine > a.txt

    local out rc=0
    out=$(run_refresh "$TEST_DIR/repo") || rc=$?
    local err
    err=$(cat "$TEST_DIR/refresh.err")

    assert_true $rc "a refusal never fails the close"
    assert_equals "" "$out" "stdout stays empty"
    assert_equals "mine" "$(cat a.txt)" "the local edit is not clobbered"
    assert_false "$([ -e c.txt ]; echo $?)" "nothing was half-applied"
    assert_contains "$err" "WARNING" "the refusal is loud"
    assert_contains "$err" "read-tree -m -u" "and names the command to run"
    teardown
}

test_refresh_is_silent_when_already_current() {
    echo "=== Testing bl-refresh does nothing on a current checkout ==="
    setup
    _refresh_repo
    echo mine > b.txt

    local out rc=0
    out=$(run_refresh "$TEST_DIR/repo") || rc=$?

    assert_true $rc "exits 0"
    assert_equals "" "$out$(cat "$TEST_DIR/refresh.err")" "says nothing at all"
    assert_equals "mine" "$(cat b.txt)" "and leaves the edit alone"
    teardown
}

test_refresh_is_silent_on_a_bare_repo() {
    echo "=== Testing bl-refresh does nothing on a bare repo ==="
    setup
    git init -q --bare "$TEST_DIR/bare.git"

    local out rc=0
    out=$(run_refresh "$TEST_DIR/bare.git") || rc=$?

    assert_true $rc "exits 0"
    assert_equals "" "$out$(cat "$TEST_DIR/refresh.err")" "says nothing at all"
    teardown
}

test_refresh_leaves_a_checkout_on_another_branch() {
    echo "=== Testing bl-refresh ignores a checkout not on the moved branch ==="
    setup
    _refresh_repo
    git checkout -q -b feature
    _refresh_deliver

    local out rc=0
    out=$(run_refresh "$TEST_DIR/repo") || rc=$?

    assert_true $rc "exits 0"
    assert_equals "" "$out$(cat "$TEST_DIR/refresh.err")" "says nothing at all"
    assert_equals "one" "$(cat a.txt)" "the feature checkout is untouched"
    teardown
}

test_refresh_leaves_a_detached_head() {
    echo "=== Testing bl-refresh ignores a detached HEAD ==="
    setup
    _refresh_repo
    git checkout -q --detach
    _refresh_deliver

    local rc=0
    run_refresh "$TEST_DIR/repo" >/dev/null || rc=$?

    assert_true $rc "exits 0"
    assert_equals "" "$(cat "$TEST_DIR/refresh.err")" "says nothing"
    assert_equals "one" "$(cat a.txt)" "the detached checkout is untouched"
    teardown
}

test_refresh_skips_a_nested_delivery() {
    echo "=== Testing bl-refresh ignores a close delivered into work/<target> ==="
    setup
    _refresh_repo
    _refresh_deliver

    local rc=0
    run_refresh "$TEST_DIR/repo" ',"command":{"id":"bl-2","target":"bl-1"}' \
        >/dev/null || rc=$?

    assert_true $rc "exits 0"
    assert_equals "" "$(cat "$TEST_DIR/refresh.err")" "says nothing"
    assert_equals "one" "$(cat a.txt)" "not this checkout's delivery"
    teardown
}

test_refresh_warns_but_waits_on_a_staged_index() {
    echo "=== Testing bl-refresh will not guess an <old> under staged edits ==="
    setup
    _refresh_repo
    _refresh_deliver
    echo staged > b.txt
    git add b.txt

    local rc=0
    run_refresh "$TEST_DIR/repo" >/dev/null || rc=$?

    assert_true $rc "exits 0"
    assert_contains "$(cat "$TEST_DIR/refresh.err")" "left alone" "and says why"
    assert_equals "staged" "$(git show :b.txt)" "the staged edit is kept"
    assert_false "$(_index_is_tip; echo $?)" "nothing was moved"
    teardown
}

test_refresh_protocol_handshake() {
    echo "=== Testing bl-refresh protocol handshake ==="
    setup
    assert_equals '{"protocol":[1],"ops":["close"]}' \
        "$("$REPO_ROOT/bin/bl-refresh" protocol)" "declares close only"
    local rc=0
    printf '{}' | "$REPO_ROOT/bin/bl-refresh" close pre >/dev/null 2>&1 || rc=$?
    assert_true $rc "and abstains outside close.post"
    teardown
}
