
### modify default history functions.
# keep a big history, append instead of overwriting.
export HISTSIZE=1000000
export HISTSIZE=1000000
shopt -s histappend # Always append, don't start new history.
HISTCONTROL=ignoreboth # Ignore duplicates and lines beginning with ' '.
SHELL_SESSION_HISTORY=0 # Solves how OSX doesn't want to save bash history.

# Save and reload history at each prompt.
export PROMPT_COMMAND="history -a; history -c; history -r;"