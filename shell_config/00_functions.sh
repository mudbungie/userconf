# Keep doing it until it works.
function retry {
    "$@"
    while [ $? != 0 ]
    do
        "$@"
    done
}

# pipe it into jq and back out
function rectify_json {
    if ! [[ $(which jq) ]]; then
        echo "jq not installed"
        return 1
    fi
    if ! [[ $(which sponge) ]]; then
        echo "sponge not installed"
        return 2
    fi
    if [[ $(jq . $1) ]]; then
        jq . $1 |sponge $1
    fi
}

# Non-clobbering path addition.
function add_to_path {
    pathlines=$(echo PATH|sed 's/:/\n/g') # Split path by lines.
    if ! echo $PATH |grep -q $1 ; then
        export PATH="$PATH:$1"
    fi
}

function prepend_to_path {
    pathlines=$(echo PATH|sed 's/:/\n/g') # Split path by lines.
    if ! echo $PATH |grep -q $1 ; then
        export PATH="$1:$PATH"
    fi
}

function print_path {
    echo $PATH | sed 's/:/\n/g'
}

function get_char_limited_path {
    CWD=`pwd`
    CWD=$(echo $CWD | sed "s*$HOME*~*g")
    CWDlen=$(echo $CWD | wc -c)
    # Concatenate beginning and ends of long paths around '...'
    if [ $CWDlen -gt 37 ]; then
        CWD="${CWD:0:18}...${CWD: -18}"
    fi
    echo $CWD
}

function waist {
    # Take specific line from file.
    # Takes one or two positional arguments, of which the last is a line number.
    # If there are two arguements, the first is a filename, 
    if [ $2 ] ; then
        FILENAME=$1
        LINE=$2
    else
        FILENAME='-'
        LINE=$1
    fi
    cat $FILENAME | head -n $LINE | tail -n 1
}


function show_git_branch {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

function bash_colors {
    export RESTORE=$(echo -en '\033[0m')
    export RED=$(echo -en '\033[00;31m')
    export GREEN=$(echo -en '\033[00;32m')
    export YELLOW=$(echo -en '\033[00;33m')
    export BLUE=$(echo -en '\033[00;34m')
    export MAGENTA=$(echo -en '\033[00;35m')
    export PURPLE=$(echo -en '\033[00;35m')
    export CYAN=$(echo -en '\033[00;36m')
    export LIGHTGRAY=$(echo -en '\033[00;37m')
    export LRED=$(echo -en '\033[01;31m')
    export LGREEN=$(echo -en '\033[01;32m')
    export LYELLOW=$(echo -en '\033[01;33m')
    export LBLUE=$(echo -en '\033[01;34m')
    export LMAGENTA=$(echo -en '\033[01;35m')
    export LPURPLE=$(echo -en '\033[01;35m')
    export LCYAN=$(echo -en '\033[01;36m')
    export WHITE=$(echo -en '\033[01;37m')
}

# xfce4 configurations
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

function set_xfce4_shortcuts {
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

    set_command_shortcut "<Primary><Alt>l" "xflock4"
    set_command_shortcut "<Super>l" "xflock4"
    set_command_shortcut "<Super>t" "xfce4-terminal"
    set_command_shortcut "<Super>h" "qvm-run -a personal-ssh gnome-terminal"
    set_command_shortcut "<Super>m" "qvm-run -a vpn-gateway gnome-terminal"
    set_command_shortcut "<Super>n" "qvm-run -a sys-net gnome-terminal"
    set_command_shortcut "<Super>u" "qvm-run -a untrusted-debian gnome-terminal"
    set_command_shortcut "<Super>f" "qvm-run -a personal firefox"
    set_command_shortcut "<Super>g" "qvm-run -a gmail firefox"
    set_command_shortcut "<Super>v" "qvm-run -a dev gnome-terminal"
    set_command_shortcut "<Super>k" "qvm-run -a keepass keepassx"
}

function mac_compliant_inline_sed {
    # ffs mac has to have their own sed flags
    if $(uname |grep -q "Darwin")
    then 
        sed -i .bak "$1" "$2"
    else
        sed -i "$1" ""$2
    fi
}

function env_assume_role {
    role_arn=$1

    OUTPUT=$(aws sts assume-role --role-arn "$1" --role-session-name "session" 2>&1) 

    if echo $OUTPUT | grep "InvalidClientTokenId"; then
        OUTPUT=$(aws --profile default sts assume-role --role-arn "$1" --role-session-name "session")
    fi
    
    AccessKeyId=$(echo $OUTPUT | jq -r .Credentials.AccessKeyId)
    SecretAccessKey=$(echo $OUTPUT | jq -r .Credentials.SecretAccessKey)
    SessionToken=$(echo $OUTPUT | jq -r .Credentials.SessionToken)

    export AWS_ACCESS_KEY_ID=$AccessKeyId
    export AWS_SECRET_ACCESS_KEY=$SecretAccessKey
    export AWS_SESSION_TOKEN=$SessionToken
}

function source_if_exists {
    [ -f "$1" ] && source "$1"
}

function is_git_repo {
    git rev-parse --is-inside-work-tree &>/dev/null
    return $?
}

