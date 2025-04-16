if [ -f ~/.bash_localrc ]; then
    source ~/.bash_localrc
fi

source_if_exists $HOME/.local/bin/env

