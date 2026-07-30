#!/bin/bash
#
# Who a commit is by. The invariant is enforced in two places because neither
# alone is enough: exported GIT_AUTHOR_*/GIT_COMMITTER_*
# (shell_config/22_git_identity.sh) outrank a repo's own .git/config, which is
# where a wrong identity would otherwise come from, and githooks-global/chain
# catches the one thing the environment cannot - an explicit
# `git commit --author=`.
#
# What must NOT be caught matters as much: a replayed upstream commit, and the
# task tracker's own store identity. Both are here.
#
# The sandbox machine (tests/lib.sh) supplies HOME, the global gitconfig and a
# repo, with the real machine's environment scrubbed, so no case can pass by
# accident of the developer's own setup.
#

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
