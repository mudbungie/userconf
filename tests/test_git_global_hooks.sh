#!/bin/bash
#
# githooks-global/ as a mechanism, rather than the invariants it carries:
# that it does not cost a repo its own hooks, that it leaves throwaway repos
# alone, and that the dir is one script under many names with the behaviour-
# changing hook names deliberately left out.
#
# The sandbox machine (tests/lib.sh) supplies HOME, the global gitconfig and a
# repo, with the real machine's environment scrubbed.
#
test_repo_local_hooks_still_run() {
    echo "=== Testing that taking over core.hooksPath costs a repo nothing ==="
    setup
    _sandbox_machine

    # The reason global hooks are usually a trap: core.hooksPath replaces
    # .git/hooks wholesale, so a repo's own gate silently stops running.
    local marker="$TEST_DIR/repo-hook-ran"
    printf '#!/bin/sh\necho ran > %s\n' "$marker" > .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit

    echo change > file.txt
    git add file.txt
    git commit -qm "a commit in a repo with its own hook"

    assert_equals "ran" "$(cat "$marker" 2>/dev/null)" \
        "the repo's own pre-commit still runs under the global hooks dir"

    # And a repo hook that fails still fails the commit.
    local before status
    printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit
    before=$(git rev-parse HEAD)
    echo more > file.txt
    git add file.txt
    git commit -qm "should not land" >/dev/null 2>&1 && status=0 || status=$?
    assert_false "$status" "a failing repo hook still refuses the commit"
    assert_equals "$before" "$(git rev-parse HEAD)" "and nothing landed"

    _leave_sandbox
}

test_hook_farm_is_one_script_under_many_names() {
    echo "=== Testing the shape of githooks-global/ ==="

    local dir="$REPO_ROOT/githooks-global"
    assert_true "$([ -x "$dir/chain" ]; echo $?)" "chain is executable"

    local name broken=""
    for name in "$dir"/*; do
        [ "${name##*/}" = chain ] && continue
        [ -L "$name" ] && [ "$(readlink "$name")" = chain ] || broken="$broken ${name##*/}"
    done
    assert_equals "" "$broken" "every hook name is a symlink to chain"

    assert_true "$([ -L "$dir/commit-msg" ]; echo $?)" \
        "commit-msg is linked - it is the hook that enforces"

    # Absence and success are not the same thing for these three: git changes
    # what it does when the hook merely exists, so a stub is not a no-op.
    for name in push-to-checkout proc-receive fsmonitor-watchman; do
        assert_false "$([ -e "$dir/$name" ]; echo $?)" \
            "$name is deliberately not linked"
    done
}

test_throwaway_repos_are_left_alone() {
    echo "=== Testing that a test harness's sandbox is not policed ==="
    setup
    _sandbox_machine

    # The real case: a suite that does `git init` in a temp dir and commits
    # under a fixture identity. Enforcing there stops no sloppiness - the repo
    # does not outlive the test - and refuses a commit the suite depends on.
    export TMPDIR="$TEST_DIR/harness"
    mkdir -p "$TMPDIR/sandbox"
    cd "$TMPDIR/sandbox" || return 1
    git init -q
    echo fixture > f
    git add f

    local status
    git -c user.email=t@t.local -c user.name=T commit -q -F - >/dev/null 2>&1 <<'EOF' \
        && status=0 || status=$?
A fixture commit

Co-Authored-By: Claude <noreply@anthropic.com>
EOF

    assert_true "$status" "the sandbox commit is not refused"
    assert_equals "t@t.local" "$(git log -1 --format=%ae)" \
        "the fixture identity is left exactly as the harness set it"
    assert_contains "$(git log -1 --format=%B)" "Co-Authored-By: Claude" \
        "and the message is not rewritten under it either"

    _leave_sandbox
}

test_this_repo_is_not_its_own_blind_spot() {
    echo "=== Testing that userconf's own core.hooksPath does not exempt it ==="

    # A repo with its own core.hooksPath replaces the global dir outright, and
    # this repo has one. The link is how the enforcement gets back in.
    local link="$REPO_ROOT/.githooks/commit-msg"
    assert_equals "../githooks-global/chain" "$(readlink "$link")" \
        ".githooks/commit-msg links to the machine-wide chain"
    assert_true "$([ -x "$link" ]; echo $?)" "and it resolves to something runnable"
}

test_gitconfig_points_the_machine_at_the_hooks() {
    echo "=== Testing that the shipped gitconfig wires it up ==="

    local config
    config=$(cat "$REPO_ROOT/dotfiles/gitconfig")
    assert_contains "$config" '^    hooksPath = ~/userconf/githooks-global$' \
        "dotfiles/gitconfig sets core.hooksPath"
}
