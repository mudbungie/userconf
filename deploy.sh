#!/bin/bash

function find_best_hash_function {
    declare -a hash_functions=("sha512sum" "sha512" "sha256sum" "sha256"
        "sha1sum" "sha1" "shasum" "md5sum" "md5")
    for hash_function in "${hash_functions[@]}"; do
        if command -v "$hash_function" >/dev/null; then
            echo "$hash_function"
            return 0
        fi
    done
    return 1
}

# Move the file to .bak, recursively, so that you never squash.
function backup_file {
    if [ -e "$1" ]; then 
        backup_file "$1.bak"
        echo "Backing up $1 to $1.bak"
        mv  "$1" "$1.bak"
    fi
}

function unbackup_file {
    if [ -e "$1.bak" ] ; then
        echo "Restoring $1.bak to $1"
        mv "$1.bak" "$1"
        unbackup_file "$1.bak"
    fi
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

    # Programs that I want installed.
    local programs="vim wget curl python3 git jq"
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

function install_not_packages {
    # Node and python and stuff
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.2/install.sh | bash
    curl -sSL https://install.python-poetry.org | python3 -
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

function replace_file_if_new {
    conf=$1
    hash_function=$(find_best_hash_function)
    if [ -f "$HOME/$conf" ]; then
        original_hash=$($hash_function $HOME/$conf | cut -d ' ' -f 1)
        echo "Original file hash: $original_hash"
        new_hash=$($hash_function $conf | cut -d ' ' -f 1)
        echo "New file hash: $new_hash"
        if [ $original_hash == $new_hash ]; then
            echo "$HOME/$conf up to date, leaving unchanged."
        else
            echo "Installing $HOME/$conf"
            backup_file "$HOME/$conf"
            cp "$conf" "$HOME/$conf"
        fi
    else
        echo "Installing $HOME/$conf"
        cp "$conf" "$HOME/$conf"
    fi

}

function backup_file_if_new_content {
    file=$1
    content=$2

    # If file doesn't exist, nothing to back up
    [ -f "$file" ] || return 0

    file_content=$(cat "$file")
    hash_function=$(find_best_hash_function)
    new_hash=$(echo "$content" | $hash_function | cut -d ' ' -f 1)
    old_hash=$(echo "$file_content" | $hash_function | cut -d ' ' -f 1)
    if [ "$new_hash" != "$old_hash" ] ; then
        backup_file "$file"
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

function install_dotfiles {
    for appconfig in dotfiles/*; do
        filename=${appconfig##*/}
        backup_file "$HOME/.$filename"
        cp "$appconfig" "$HOME/.$filename"
    done
}

function configure_user {
    echo "Configuring user..."
    ensure_path_is_correct
    ensure_requirements
    make_notes_dir
    make_local_bin_dir
    install_packages
    install_shell_hooks
    install_dotfiles
    echo "Done configuring user."
}

if [[ "$1" == '-i' ]] ; then
    configure_user;
else
    echo "use flag -i if you really mean it"
fi
