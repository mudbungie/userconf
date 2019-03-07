# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Include custom bash functions.
source "$HOME/.bash_functions.sh"

# Enable the color shortcuts. Preceding bash_functions may break without this.
bash_colors

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
# Not supported on OSX, so suppress the error.
shopt -s globstar 2>/dev/null

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

#if [ "$color_prompt" = yes ]; then
#    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#else
#    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
#fi
#unset color_prompt force_color_prompt

## If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# ls shortcuts
alias ll='ls -l'
alias la='ls -A'
alias l='ls -CF'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

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

### modify default history functions.
# keep a big history, append instead of overwriting.
export HISTSIZE=1000000
export HISTSIZE=1000000
shopt -s histappend # Always append, don't start new history.
HISTCONTROL=ignoreboth # Ignore duplicates and lines beginning with ' '.
SHELL_SESSION_HISTORY=0 # Solves how OSX doesn't want to save bash history,

# Save and reload history at each prompt.
export PROMPT_COMMAND="history -a; history -c; history -r;"

# Use the shell prompt defined in ~/.bash_functions.sh
PS1=$(gen_PS1)

# Add my local bins to the path.
add_to_path "$HOME/bin"
add_to_path "$HOME/.local/bin"

# Use vim.
EDITOR=vim
VISUAL=$EDITOR

# Include pythonrc
export PYTHONSTARTUP="$HOME/.pythonrc"

# Aliases
alias ip?='curl doihaveinter.net/IP'
alias ll='ls -al'
alias kinit='kinit -f'
alias wcc='wc -c'

# Domain-specific configuration.
if hostname -f |grep -q 'amazon.com' ; then
    add_to_path "$HOME/.toolbox/bin"
    add_to_path '/apollo/env/SDETools/bin'
    add_to_path '/apollo/env/envImprovement/bin'
    add_to_path '/apollo/bin'
    add_to_path '/apollo/sbin'
    add_to_path '/apollo/env/ApolloCommandLine/bin'
    add_to_path '/apollo/env/AmazonAwsCli/bin'
    add_to_path '/apollo/env/OdinTools/bin'
    add_to_path '/usr/kerberos/bin'
    add_to_path '/apollo/env/OctaneBrazilTools/bin'
    add_to_path '/apollo/env/BrazilCLI/public-bin/brazil'

    sed -i 's/mudbungie/oribi/g' ~/.gitconfig
    sed -i 's/gmail/amazon/g' ~/.gitconfig

    alias cmwb='/apollo/env/ChangeManagementWorkBench/bin/ChangeManagementWorkbench'
    alias bo='brazil-octane'
    alias mwinit='mwinit -o'
    alias bre='brazil-runtime-exec'

    # Fix internal certs
    export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-bundle.crt

    alias cmex='OVERRIDE_ENVROOT=/apollo/env/ChangeManagementWorkbench /home/oribi/workspaces/ChangeManagementWorkbenchExtensions/src/ChangeManagementWorkbenchExtensions/my_extensions/bin/ChangeManagementWorkbenchMod'
fi 

# awscli autocomplete
if [ $(which aws) ] && [ $(which aws_completer) ]; then
    complete -C `which aws_completer` aws
fi

# fix stupid keyboard bug
if [[ $(uname -a |grep qubes) ]] ; then
    xmodmap -e 'keycode 94 = backslash bar'
fi

# DO NOT ADD AFTER THIS LINE. LOCAL CONFIG SHOULD BE LAST.
# Include local configuration.
if [ -f "$HOME/.bash_localrc" ]; then
    source "$HOME/.bash_localrc"
else
    echo "# Local bash configuration for this machine." >> "$HOME/.bash_localrc"

fi

