# Enable the color shortcuts. Preceding bash_functions may break without this.
bash_colors

# Enforce color settings
force_color_prompt=yes
color_prompt=yes

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

# Add my local bins to the path.
add_to_path "$HOME/bin"
add_to_path "$HOME/.local/bin"

# Use vim.
EDITOR=vim
VISUAL=$EDITOR

# Include pythonrc
export PYTHONSTARTUP="$HOME/.pythonrc"