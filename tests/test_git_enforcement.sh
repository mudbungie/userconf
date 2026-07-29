#!/bin/bash
#
# Two commit invariants, enforced for every repo on the machine:
#   - the author and committer are this machine's identity;
#   - the message carries no AI authorship line.
#
# They are enforced in two places because neither alone is enough. Exported
# GIT_AUTHOR_*/GIT_COMMITTER_* (shell_config/22_git_identity.sh) outrank a
# repo's own .git/config, which is where a wrong identity would otherwise come
# from; githooks-global/chain, reached by core.hooksPath, catches the one thing
# the environment cannot - an explicit `git commit --author=`.
#
# Every case runs on a sandbox machine: its own HOME, its own global gitconfig,
# and the environment scrubbed of anything the real machine exports, so no test
# can pass by accident of the developer's own setup.
#

SANDBOX_EMAIL="sandbox@example.invalid"

# A machine with one identity and this repo as its global hooks dir, plus a
# repo on it holding one commit. Leaves the shell inside that repo.
_sandbox_machine() {
    _ENFORCE_PRIOR_HOME=$HOME
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"
    unset XDG_CONFIG_HOME GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
    unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

    printf '[user]\n\tname = Sandbox\n\temail = %s\n[core]\n\thooksPath = %s\n' \
        "$SANDBOX_EMAIL" "$REPO_ROOT/githooks-global" > "$HOME/.gitconfig"

    mkdir -p "$TEST_DIR/repo"
    cd "$TEST_DIR/repo" || return 1
    git init -q
    echo seed > seed.txt
    git add seed.txt
    git commit -qm "seed"
}

_leave_sandbox() {
    export HOME="$_ENFORCE_PRIOR_HOME"
    teardown
}

test_identity_is_exported_from_global_config() {
    echo "=== Testing that the shell exports the machine's git identity ==="
    setup
    _sandbox_machine

    # A subshell so the export cannot leak into the rest of the suite.
    local out
    out=$(source "$REPO_ROOT/shell_config/22_git_identity.sh"
          echo "$GIT_AUTHOR_EMAIL|$GIT_COMMITTER_EMAIL|$GIT_AUTHOR_NAME")
    assert_equals "$SANDBOX_EMAIL|$SANDBOX_EMAIL|Sandbox" "$out" \
        "author and committer identity are both exported"

    # An identity-less machine exports nothing rather than exporting an empty
    # string, which git would read as a real (and invalid) identity.
    rm "$HOME/.gitconfig"
    out=$(source "$REPO_ROOT/shell_config/22_git_identity.sh"
          echo "${GIT_AUTHOR_EMAIL-unset}")
    assert_equals "unset" "$out" "no identity on the machine exports no identity"

    _leave_sandbox
}

test_export_overrides_repo_local_identity() {
    echo "=== Testing that a repo cannot configure its way to another author ==="
    setup
    _sandbox_machine

    # The accident this defends against: one command inside one clone.
    git config user.email "wrong@example.invalid"
    git config user.name "Wrong Person"

    local author
    author=$(source "$REPO_ROOT/shell_config/22_git_identity.sh"
             echo change > file.txt
             git add file.txt
             git commit -qm "a commit in a misconfigured repo"
             git log -1 --format=%ae)
    assert_equals "$SANDBOX_EMAIL" "$author" \
        "the exported identity beats the repo's own user.email"

    _leave_sandbox
}

test_commit_refused_for_a_foreign_author() {
    echo "=== Testing that --author= is refused ==="
    setup
    _sandbox_machine

    local before out status
    before=$(git rev-parse HEAD)
    echo change > file.txt
    git add file.txt
    # `|| status=$?` and never a bare call: the runner runs under `set -e`, so
    # an unguarded failure would take the whole suite down with it.
    out=$(git commit -m "sneaking one in" \
              --author="Someone Else <else@example.invalid>" 2>&1) \
        && status=0 || status=$?

    assert_false "$status" "the commit is refused"
    assert_contains "$out" "AUTHOR email is <else@example.invalid>" \
        "the refusal names the offending address"
    assert_contains "$out" "git config --global user.email" \
        "and names the authority it checked against, not a file that may not exist"
    assert_equals "$before" "$(git rev-parse HEAD)" "no commit was made"

    _leave_sandbox
}

test_balls_store_identity_is_allowed() {
    echo "=== Testing that the balls store identity is exempt ==="
    setup
    _sandbox_machine

    # balls (the task tracker) seals its stores as <balls@localhost> for both
    # roles - the one sanctioned service identity besides the human's.
    local status
    echo change > file.txt
    git add file.txt
    GIT_COMMITTER_NAME=balls GIT_COMMITTER_EMAIL=balls@localhost \
        git commit -qm "sealed by the store" \
            --author="balls <balls@localhost>" \
        && status=0 || status=$?

    assert_true "$status" "the commit is accepted"
    assert_equals "balls@localhost" "$(git log -1 --format=%ae)" \
        "the author survives as the store identity"

    _leave_sandbox
}

test_ai_authorship_lines_are_stripped() {
    echo "=== Testing that AI authorship lines never reach a commit ==="
    setup
    _sandbox_machine

    echo change > file.txt
    git add file.txt
    git commit -q -F - <<'EOF'
Do the real work

The body that explains it.

Co-Authored-By: Claude <noreply@anthropic.com>
🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF

    local msg
    msg=$(git log -1 --format=%B)
    assert_not_contains "$msg" "Claude" "no trace of the tool survives"
    assert_not_contains "$msg" "anthropic" "no trace of the vendor survives"
    assert_contains "$msg" "Do the real work" "the subject survives"
    assert_contains "$msg" "The body that explains it." "the body survives"

    _leave_sandbox
}

test_stripping_leaves_human_credit_and_prose_alone() {
    echo "=== Testing that the strip is anchored, not a keyword hunt ==="
    setup
    _sandbox_machine

    echo change > file.txt
    git add file.txt
    git commit -q -F - <<'EOF'
Add the parser

Discussed with a colleague; the tables were generated with a script.

Co-Authored-By: A Human <human@example.invalid>
EOF

    local msg
    msg=$(git log -1 --format=%B)
    assert_contains "$msg" "Co-Authored-By: A Human" "a human co-author is kept"
    assert_contains "$msg" "generated with a script" "prose is not touched"

    _leave_sandbox
}

test_replayed_commits_keep_their_original_author() {
    echo "=== Testing that cherry-pick does not fight the enforcement ==="
    setup
    _sandbox_machine

    # A commit that is genuinely someone else's, as an `am` or a fetch would
    # deliver it. --no-verify is how the fixture gets past the hook; nothing in
    # normal use needs it.
    git checkout -qb theirs
    echo theirs > theirs.txt
    git add theirs.txt
    git commit -q --no-verify -m "their work" \
        --author="Upstream Dev <upstream@example.invalid>"

    git checkout -q master 2>/dev/null || git checkout -q main
    local out status
    out=$(git cherry-pick theirs 2>&1) && status=0 || status=$?

    assert_true "$status" "the cherry-pick succeeds"
    assert_equals "upstream@example.invalid" "$(git log -1 --format=%ae)" \
        "the original author is preserved, not rewritten or rejected"
    assert_equals "$SANDBOX_EMAIL" "$(git log -1 --format=%ce)" \
        "this machine is recorded as the committer"

    _leave_sandbox
}

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
