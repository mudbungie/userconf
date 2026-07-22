# nvm's completion script is bash-only (it calls `complete`); nvm.sh itself is
# shell-agnostic and lives in the untagged half of slot 50. NVM_DIR is derived
# here rather than read from that half: files sharing a slot load in glob
# order, so neither may depend on the other.
[ -s "${NVM_DIR:-$HOME/.nvm}/bash_completion" ] && \. "${NVM_DIR:-$HOME/.nvm}/bash_completion"
