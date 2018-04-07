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
    programs="vim wget curl python3 git"
    echo "Installing the following programs: $programs."
    # If root, don't use sudo.
    if [ $(id -u) != 0 ]; then
        SUDO=sudo
    else
        unset SUDO
    fi

    #echo $SUDO $pkgmgr install -y $programs
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
    rm -rf ./userconf
    echo "Done installing configuration files."
}

## Back up current confs and download mine.
#declare -a confs=(".bashrc" ".vimrc" ".sqliterc" ".pythonrc" ".profile" ".bash_functions.sh")
#for conf in "${confs[@]}"; do
#    backup_file "$HOME/$conf"
#	echo "Installing $HOME/$conf"
#	wget -qO "$HOME/$conf" "$config_url/$conf"
#done

