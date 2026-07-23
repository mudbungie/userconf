#!/bin/bash
#
# Repository shape: expected files exist, no stale paths, scripts parse,
# and the core shell_config files can be sourced together.
#

SHELL_CONFIG_FILES=(
    "shell_config/00_functions.sh"
    "shell_config/20_set_variables.sh"
    "shell_config/20_set_variables.bash.interactive.sh"
    "shell_config/25_colors.interactive.sh"
    "shell_config/30_history.bash.interactive.sh"
    "shell_config/30_history.zsh.interactive.sh"
    "shell_config/40_prompt.bash.interactive.sh"
    "shell_config/40_prompt.zsh.interactive.sh"
    "shell_config/50_mise.bash.interactive.sh"
    "shell_config/50_mise.zsh.interactive.sh"
    "shell_config/60_aliases.interactive.sh"
    "shell_config/70_githelpers.sh"
    "shell_config/99_local.sh"
)

test_file_structure() {
    echo "=== Testing file structure ==="

    local files=(
        "deploy.sh"
        "orb_profile"
        "${SHELL_CONFIG_FILES[@]}"
        "dotfiles/gitconfig"
        "dotfiles/pythonrc"
        "dotfiles/sqliterc"
        "dotfiles/vimrc"
    )

    for file in "${files[@]}"; do
        if [ -f "$REPO_ROOT/$file" ]; then
            pass "File exists: $file"
        else
            fail "File exists" "$file" "missing"
        fi
    done
}

test_path_references() {
    echo "=== Testing path references (checking for stale paths) ==="

    # Check for old config path references that should be shell_config
    if grep -q "userconf/config/" "$REPO_ROOT/deploy.sh"; then
        fail "deploy.sh path reference" "userconf/shell_config/" "userconf/config/ (stale)"
    else
        pass "deploy.sh uses correct shell_config path"
    fi

    if grep -q "userconf/config/" "$REPO_ROOT/dotfiles/gitconfig"; then
        fail "gitconfig path reference" "userconf/shell_config/" "userconf/config/ (stale)"
    else
        pass "gitconfig uses correct shell_config path"
    fi
}

test_syntax_check() {
    echo "=== Testing shell script syntax ==="

    local scripts=(
        "deploy.sh"
        "orb_profile"
        "${SHELL_CONFIG_FILES[@]}"
    )

    for script in "${scripts[@]}"; do
        if bash -n "$REPO_ROOT/$script" 2>/dev/null; then
            pass "Syntax valid: $script"
        else
            fail "Syntax check" "valid bash syntax" "syntax error in $script"
        fi
    done
}

test_functions_sourceable() {
    echo "=== Testing that config files can be sourced together ==="

    # Test that key files can be sourced (skip 20_set_variables which loads bash_completion)
    local result
    result=$(bash --norc --noprofile -c '
        set -e
        export HOME='"$HOME"'
        source '"$REPO_ROOT"'/shell_config/00_functions.sh
        source '"$REPO_ROOT"'/shell_config/30_history.bash.interactive.sh
        source '"$REPO_ROOT"'/shell_config/40_prompt.bash.interactive.sh
        source '"$REPO_ROOT"'/shell_config/70_githelpers.sh
        echo "success"
    ' 2>&1) || result="error"

    if echo "$result" | grep -q "success"; then
        pass "Core shell_config files source without error"
    else
        fail "Sourcing shell_config" "no errors" "$result"
    fi
}
