#!/bin/bash

repo="https://github.com/mudbungie/userconf"

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

function install_confs {
    echo "Installing configuration files."
    if [[ ! $(which git) ]] ; then
        echo "git not installed"
        return 1
    fi
    backup_file userconf
    git clone $repo
    cd userconf
    confs=$(git ls-files |grep -vE 'deploy.sh|.bash_localrc')
    hash_function=$(find_best_hash_function)
    for conf in $confs; do
        if [ -f "$HOME/$conf" ]; then
            original_hash=$($hash_function $HOME/$conf | cut -d ' ' -f 1)
            new_hash=$($hash_function $conf | cut -d ' ' -f 1)
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
    done
    if [ ! -f "$HOME/.bash_localrc" ] ; then
        echo "Installing stub $HOME/.bash_localrc"
        cp ".bash_localrc" "$HOME"
    fi
    cd ../
    echo "Cleaning up temporary directory."
    rm -rf userconf
    unbackup_file userconf
    echo "Done installing configuration files."
}

if [[ "$1" == '-i' ]] ; then
    install_confs;
fi
