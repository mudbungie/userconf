#!/usr/bin/env bash

function set_xfconf_value {
	# set_xfconf_value path value
	xfconf-query -c xfce4-keyboard-shortcuts -p "$1" -r
	xfconf-query -c xfce4-keyboard-shortcuts -p "$1" -s "$2" -n -t string
	return $?
}

function set_wm_shortcut {
	# set_wm_shortcut shortcut value
	set_xfconf_value "/xfwm4/custom/$1" "$2"
	return $?
}

function set_command_shortcut {
	# set_command_shortcut shortcut value
	set_xfconf_value "/commands/custom/$1" "$2"
	return $?
}


set_wm_shortcut "<Primary><Super>KP_1" "tile_down_left_key"
set_wm_shortcut "<Primary><Super>KP_2" "tile_down_key"
set_wm_shortcut "<Primary><Super>KP_3" "tile_down_right_key"
set_wm_shortcut "<Primary><Super>KP_4" "tile_left_key"
set_wm_shortcut "<Primary><Super>KP_5" "maximize_window_key"
set_wm_shortcut "<Primary><Super>KP_6" "tile_right_key"
set_wm_shortcut "<Primary><Super>KP_7" "tile_up_left_key"
set_wm_shortcut "<Primary><Super>KP_8" "tile_up_key"
set_wm_shortcut "<Primary><Super>KP_9" "tile_up_right_key"
set_wm_shortcut "<Primary><Shift>w" "move_window_workspace_1_key"
set_wm_shortcut "<Primary><Shift>e" "move_window_workspace_2_key"
set_wm_shortcut "<Primary><Shift>s" "move_window_workspace_3_key"
set_wm_shortcut "<Primary><Shift>d" "move_window_workspace_4_key"
set_wm_shortcut "<Super>w" "workspace_1_key"
set_wm_shortcut "<Super>e" "workspace_2_key"
set_wm_shortcut "<Super>s" "workspace_3_key"
set_wm_shortcut "<Super>d" "workspace_4_key"

set_command_shortcut "<Primary><Alt>l" "xscreensaver-command -lock"
set_command_shortcut "<Super>t" "xfce4-terminal"
set_command_shortcut "<Super>h" "qvm-run -a personal-ssh gnome-terminal"
set_command_shortcut "<Super>m" "qvm-run -a vpn-gateway gnome-terminal"
set_command_shortcut "<Super>n" "qvm-run -a sys-net gnome-terminal"
set_command_shortcut "<Super>u" "qvm-run -a untrusted-debian gnome-terminal"
set_command_shortcut "<Super>f" "qvm-run -a personal firefox"
set_command_shortcut "<Super>g" "qvm-run -a gmail firefox"
set_command_shortcut "<Super>v" "qvm-run -a dev gnome-terminal"


