#!/bin/bash

repo="https://github.com/mudbungie/userconf"

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
    programs="vim wget curl python3 git ack"
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
    confs=$(git ls-files |grep -v deploy.sh)
    for conf in $confs; do
        echo "Installing $HOME/$conf"
        backup_file "$HOME/$conf"
        cp "$conf" "$HOME/$conf"
    done
    cd ../
    rm -rf userconf
    unbackup_file userconf
    echo "Done installing configuration files."
}

