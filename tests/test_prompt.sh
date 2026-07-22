#!/bin/bash
#
# shell_config/40_prompt.bash.interactive.sh and shell_config/70_githelpers.sh
#

test_gen_PS1() {
    echo "=== Testing gen_PS1 ==="
    setup

    source "$REPO_ROOT/shell_config/40_prompt.bash.interactive.sh"

    local ps1
    ps1=$(gen_PS1)

    assert_contains "$ps1" '\u' "PS1 contains username placeholder"
    assert_contains "$ps1" 'get_char_limited_path' "PS1 uses get_char_limited_path"

    # Should end with $ or # depending on user
    if [ "$(id -u)" -eq 0 ]; then
        assert_contains "$ps1" '#' "PS1 ends with # for root"
    else
        assert_contains "$ps1" '\$' "PS1 ends with $ for regular user"
    fi

    # Test custom hostname option
    ps1=$(gen_PS1 -h "customhost")
    assert_contains "$ps1" "customhost" "gen_PS1 accepts custom hostname"

    teardown
}

test_pretty_git_format() {
    echo "=== Testing pretty_git_format ==="
    setup

    source "$REPO_ROOT/shell_config/70_githelpers.sh"

    # Test "ago" removal
    local result
    result=$(echo "hash}(2 years ago)}author" | pretty_git_format)
    assert_not_contains "$result" "ago" "pretty_git_format removes 'ago'"

    # Test month truncation
    result=$(echo "hash}(2 years, 5 months ago)}author" | pretty_git_format)
    assert_not_contains "$result" "months" "pretty_git_format truncates months"

    teardown
}
