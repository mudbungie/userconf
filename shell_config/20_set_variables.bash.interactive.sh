# Bash-only, interactive-only half of slot 20. Independent of the untagged
# half: nothing here reads anything set there, so either glob order is fine.

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
  if [ -d /etc/bash_completion.d ]; then
    for i in /etc/bash_completion.d/*.sh; do
      if [ -r "$i" ]; then
        . "$i"
      fi
    done
    unset i
  fi
fi
