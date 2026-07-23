# Colored output from the tools that offer it. Ubuntu's stock ~/.bashrc was the
# only thing that ever set this up, and deploy.sh displaces that file, so
# without this slot every machine userconf touches loses ls and grep color.
#
# Interactive-only (a script's `ls` output is parsed, not read) and untagged for
# shell: nothing here is bash- or zsh-specific.

# GNU ls reads the palette out of LS_COLORS, which dircolors generates. BSD ls
# (macOS, where dircolors does not exist) has no LS_COLORS at all and takes
# CLICOLOR plus its own -G instead. The two branches are not translations of
# each other; they are different mechanisms reaching the same result, which is
# why the test is `command -v dircolors` and not `uname`.
if command -v dircolors >/dev/null 2>&1; then
    if [ -r "$HOME/.dircolors" ]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi
    alias ls='ls --color=auto'
else
    export CLICOLOR=1
    alias ls='ls -G'
fi

# GNU and BSD grep both understand --color=auto, and auto means "only when
# stdout is a terminal", so a command substitution still gets clean bytes.
alias grep='grep --color=auto'
