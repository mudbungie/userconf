#!/bin/bash

function find_best_hash_function {
    declare -a hash_functions=("sha512sum" "sha512" "sha256sum" "sha256"
        "sha1sum" "sha1" "shasum" "md5sum" "md5")
    for hash_function in "${hash_functions[@]}"; do
        which $hash_function>/dev/null
        if [ $? -eq 0 ]; then
            echo $hash_function
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
    if [ -e $1.bak ] ; then
        echo "Restoring $1.back to $1"
        mv $1.bak $1/
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
    # Test to see what package managers are available.
    declare -a installers=("yum" "dnf" "apt" "brew")
    for installer in "${installers[@]}"; do
        if which $installer; then
            pkgmgr=$installer
            echo "Package manager $installer detected."
        fi
    done

    if [ !$installer ]; then
        echo "No package manager detected."
        return 2
    fi

    # Programs that I want installed.
    programs="vim wget curl python3 git jq"
    echo "Installing the following programs: $programs."
    # If root, don't use sudo.
    if [ $(id -u) != 0 ]; then
        SUDO=sudo
    else
        unset SUDO
    fi

    if $SUDO $pkgmgr install -y $programs; then
        echo "Installation successful."
        return 0
    else
        echo "Installation failed."
        return 1
    fi
}

function make_notes_dir {
    echo "Making daily notes directory."
    mkdir -p ~/notes/daily
}

function ensure_requirements {
    echo "Ensuring required programs"
    if [[ ! $(which git) ]] ; then
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
            echo backup_file "$HOME/$conf"
            echo cp "$conf" "$HOME/$conf"
        fi
    else
        echo "Installing $HOME/$conf"
        echo cp "$conf" "$HOME/$conf"
    fi

}

function install_bash_config_hooks {
    echo "Configuring the bash login files to include the config directory."
    backup_file ~/.profile > ~/.profile
    echo "source ~/.bashrc" > ~/.profile
    backup_file ~/.bash_profile
    echo "source ~/.profile" > ~/.bash_profile
    backup_file ~/.bashrc
    echo "source ~/userconf/config/*" > ~/.bashrc
}

function ensure_path_is_correct {
    if [ $(pwd) = /home/$USER/userconf ] ; then
        echo "Path is correct, proceeding."
    else
        echo "Repository should be cloned to ~/userconf, and this script should be run from that path."
        exit 2
    fi
}

function install_dotfiles {
    for appconfig in dotfiles/*; do
        filename=$(echo $appconfig | cut -d '/' -f 2)
        backup_file "~/.$filename"
        cp "$HOME/userconf/dotfiles/$filename" "$HOME/.$filename"
    done
}

function configure_user {
    echo "Configuring user..."
    ensure_path_is_correct
    ensure_requirements
    make_notes_dir
    install_bash_config_hooks
    install_dotfiles
    echo "Done configuring user."
}

if [[ "$1" == '-i' ]] ; then
    configure_user;
else
    echo "use flag -i if you really mean it"
fi
