#!/bin/bash
#
# What a commit message may contain: no AI authorship line, and nothing else
# touched. The strip is anchored to the start of a line and to a trailer key,
# so the two things a keyword hunt would eat - prose that mentions a tool, and
# a human co-author - are what these cases pin down.
#
# The sandbox machine (tests/lib.sh) supplies HOME, the global gitconfig and a
# repo, with the real machine's environment scrubbed.
#
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
