#!/bin/bash

# Displace a pre-existing real file so a symlink can take its place. There is
# no recursion and no chain: an existing .bak is the true original, so a second
# backup refuses rather than overwriting it. Re-running deploy therefore cannot
# accumulate .bak.bak.bak.
function backup_file {
    if [ ! -e "$1" ] && [ ! -L "$1" ]; then
        return 0
    fi
    if [ -e "$1.bak" ] || [ -L "$1.bak" ]; then
        echo "Refusing to back up $1: $1.bak already exists."
        return 1
    fi
    echo "Backing up $1 to $1.bak"
    mv "$1" "$1.bak"
}

function kill_bell {
    # Disable the terminal bell
    if [[ $(whoami) != "root" ]]; then
        echo "Bell correction cannot be done except as root."
        return 1
    fi

    if [ -e "/etc/inputrc" ] ; then
        echo "/etc/inputrc exists"
        grep 'set bell-style none' /etc/inputrc | grep -vq '#'
        if [[ $? == 0 ]]; then
            echo "bell-style none already set in /etc/inputrc"
            return 0
        else
            echo "bell-style none not set in /etc/inputrc. Appending."
            echo "set bell-style none" >> /etc/inputrc
            return 0
        fi
    else
        echo "/etc/inputrc does not exist. Unknown environment, not attempting anything."
        
    fi
}

function install_packages {
    # First package manager found wins.
    local pkgmgr= installer
    for installer in yum dnf apt brew; do
        if command -v "$installer" >/dev/null; then
            pkgmgr=$installer
            echo "Package manager $installer detected."
            break
        fi
    done

    if [ -z "$pkgmgr" ]; then
        echo "No package manager detected."
        return 2
    fi

    # The base set is a rule, not a taste: a program is here only if you cannot
    # clone or repair this repo without it (git, curl, vim), or a tracked file
    # in this repo calls it (jq in rectify_json, python3 in dotfiles/pythonrc).
    # Everything merely nice - ripgrep, fzf, direnv, tmux - is a per-machine
    # preference and belongs in that machine's own install, not here. See D4 in
    # docs/modernization.md.
    local programs="git curl vim jq python3"
    echo "Installing the following programs: $programs."

    # brew has no -y and refuses to run as root; everything else wants both.
    local -a cmd
    if [ "$pkgmgr" = brew ]; then
        cmd=(brew install $programs)
    elif [ "$(id -u)" != 0 ]; then
        cmd=(sudo "$pkgmgr" install -y $programs)
    else
        cmd=("$pkgmgr" install -y $programs)
    fi

    if "${cmd[@]}"; then
        echo "Installation successful."
        return 0
    else
        echo "Installation failed."
        return 1
    fi
}

# One version manager for every language runtime, replacing nvm (node only,
# ~100ms of sourcing per shell) and Poetry (python only). mise is not carried by
# yum/dnf/apt, so the vendor installer is the portable path; it drops a single
# binary in ~/.local/bin - a directory make_local_bin_dir creates and
# 20_set_variables.sh already puts on PATH.
# Idempotence is the presence check: an already-installed mise (from brew, or
# from the last deploy) is left alone and updates itself with `mise self-update`.
function install_mise {
    if command -v mise >/dev/null; then
        echo "mise already installed."
        return 0
    fi
    echo "Installing mise (node/python version manager)."
    # Downloaded whole, then run - not `curl | sh`. A pipeline reports the exit
    # status of `sh`, so a failed or truncated download would run as a partial
    # script and still look like a success.
    local script
    script=$(mktemp) || return 1
    if curl -fsSL https://mise.run > "$script" && sh "$script"; then
        rm -f "$script"
        return 0
    fi
    rm -f "$script"
    echo "mise installation failed; shells will start without it."
    return 1
}

function make_notes_dir {
    echo "Making daily notes directory."
    mkdir -p ~/notes/daily
}

function make_local_bin_dir {
    echo "Making local binaries directory."
    mkdir -p ~/.local/bin
}

function ensure_requirements {
    echo "Ensuring required programs"
    if ! command -v git >/dev/null ; then
        echo "git not installed"
        exit 1
    fi
}

function inject_rc_line {
    # Idempotently put a line at the top of a shell rc file, creating the file
    # if it does not exist. userconf owns its line, not the file: rc files are
    # shared territory (nvm, brew, rustup all append to them), so this injects
    # and greps rather than writing the file whole.
    # Usage: inject_rc_line <rcfile> <line>
    local rcfile="$1"
    local line="$2"

    if [ ! -f "$rcfile" ]; then
        echo "Creating $rcfile with: $line"
        echo "$line" > "$rcfile"
        return 0
    fi

    if grep -qF "$line" "$rcfile" 2>/dev/null; then
        echo "$rcfile already has: $line"
        return 0
    fi

    echo "Injecting into $rcfile: $line"
    local temp_file=$(mktemp)
    {
        echo "$line"
        echo ""
        cat "$rcfile"
    } > "$temp_file"
    backup_file "$rcfile"
    mv "$temp_file" "$rcfile"
}

function install_shell_hooks {
    echo "Installing orb_profile hooks into shell configuration files..."

    # bash: ~/.bashrc is the real config. ~/.bash_profile gets a bridge to it,
    # not a second orb_profile line - a *login* bash reads .bash_profile and
    # never .bashrc, and a login bash is what every macOS Terminal tab starts.
    # The bridge is what makes the login and non-login paths agree.
    inject_rc_line "$HOME/.bashrc" '. ~/userconf/orb_profile'
    inject_rc_line "$HOME/.bash_profile" '[ -f ~/.bashrc ] && . ~/.bashrc'

    # zsh reads ~/.zshrc for every interactive shell, login or not, so
    # ~/.zprofile would be redundant. ~/.profile is dropped with it: it is the
    # non-interactive path, where prompt and history config have no business.
    inject_rc_line "$HOME/.zshrc" '. ~/userconf/orb_profile'

    echo "Shell hooks installed. orb_profile will be sourced on shell startup."
}

function ensure_path_is_correct {
    if [ $(pwd) = $HOME/userconf ] ; then
        echo "Path is correct, proceeding."
    else
        echo "Repository should be cloned to ~/userconf, and this script should be run from that path."
        exit 2
    fi
}

# Link, do not copy: the repo stays the only home for the fact, so an edit made
# through ~/.vimrc lands in the repo where git can see it. Idempotence is
# structural - a correct link is already the answer, so there is nothing to
# compare and nothing to hash.
function link_dotfile {
    local src="$1" dest="$2"
    if [ "$(readlink "$dest")" = "$src" ]; then
        echo "$dest already links to $src"
        return 0
    fi
    backup_file "$dest" || return 1
    echo "Linking $dest -> $src"
    ln -s "$src" "$dest"
}

function install_dotfiles {
    local repo appconfig filename status=0
    repo=$(pwd)
    for appconfig in dotfiles/*; do
        filename=${appconfig##*/}
        link_dotfile "$repo/$appconfig" "$HOME/.$filename" || status=1
    done
    return $status
}

function configure_user {
    echo "Configuring user..."
    ensure_path_is_correct
    ensure_requirements
    make_notes_dir
    make_local_bin_dir
    install_packages
    install_mise
    install_shell_hooks
    install_dotfiles
    echo "Done configuring user."
}

if [[ "$1" == '-i' ]] ; then
    configure_user;
else
    echo "use flag -i if you really mean it"
fi
