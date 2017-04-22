#!/usr/bin/env bash

config_url="https://www.mudbungie.net/userconf"

# Test to see what package managers are available.
declare -a installers=("apt" "dnf")
for installer in "${installers[@]}"; do
	if which $installer; then
		pkgmgr=$installer
		echo "Package manager $installer detected."
	fi
done

# Programs that I want installed.
programs="vim wget curl python3"
echo "Installing the following programs: $programs."
echo sudo $pkgmgr install -y $programs
if sudo $pkgmgr install -y $programs; then
	echo "Installation successful."
else:
	echo "Installation failed."
fi

# Back up current confs and download mine.
declare -a confs=(".bashrc" ".vimrc" ".sqliterc")
for conf in "${confs[@]}"; do
	if [ -e "$HOME/$conf" ]; then
		echo "Backing up $HOME/$conf to $HOME/$conf.bak"
		mv $HOME/$conf $HOME/$conf.bak
	fi
	echo "Installing $HOME/$conf"
	wget -qO "$HOME/$conf" "$config_url/$conf"
done
	
