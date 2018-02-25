#!/bin/bash

config_url="https://www.mudbungie.net/userconf"

# Move the file to .bak, recursively, so that you never squash.
function backup_file {
    if [ -e "$1" ]; then 
        backup_file "$1.bak"
        echo "Backing up $1 to $1.bak"
        mv  "$1" "$1.bak"
    fi
}
    

# Test to see what package managers are available.
declare -a installers=("yum" "dnf" "apt")
for installer in "${installers[@]}"; do
	if which $installer; then
		pkgmgr=$installer
		echo "Package manager $installer detected."
	fi
done

# Programs that I want installed.
programs="vim wget curl python3 git"
echo "Installing the following programs: $programs."
# If root, don't use sudo.
if [ $(id -u) != 0 ]; then
    sudo=sudo
else
    sudo=""
fi
echo $sudo
echo $sudo $pkgmgr install -y $programs
if $sudo $pkgmgr install -y $programs; then
	echo "Installation successful."
else
	echo "Installation failed."
fi

# Back up current confs and download mine.
declare -a confs=(".bashrc" ".vimrc" ".sqliterc" ".pythonrc" ".profile" ".bash_functions.sh")
for conf in "${confs[@]}"; do
    backup_file "$HOME/$conf"
	echo "Installing $HOME/$conf"
	wget -qO "$HOME/$conf" "$config_url/$conf"
done
	
