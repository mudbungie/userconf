# zsh half of slot 30. Not a translation of the bash half: zsh reads an empty
# HISTSIZE as zero, not as unlimited, so the sizes are explicit numbers, and
# append-and-reload-at-every-prompt is a setopt rather than a PROMPT_COMMAND.

HISTFILE=${HISTFILE:-$HOME/.zsh_history}
HISTSIZE=1000000
SAVEHIST=1000000

setopt APPEND_HISTORY        # add to the file, never truncate it
setopt INC_APPEND_HISTORY    # write each command as it is entered
setopt SHARE_HISTORY         # and read back what other shells wrote
setopt EXTENDED_HISTORY      # keep timestamps, as HISTTIMEFORMAT does in bash
setopt HIST_IGNORE_ALL_DUPS  # HISTCONTROL=ignoredups
setopt HIST_IGNORE_SPACE     # HISTCONTROL=ignorespace
