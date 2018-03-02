# Keep doing it until it works.
function retry {
    "$@"
    while [ $? != 0 ]
    do
        "$@"
    done
}

# Non-clobbering path addition.
function add_to_path {
    pathlines=$(echo PATH|sed 's/:/\n/g') # Split path by lines.
    if ! echo $PATH |grep -q $1 ; then
        export PATH="$PATH:$1"
    fi
}

# Generates a PS1 value.
function gen_PS1 {
    # Arguments.
    while [ "$1" != "" ]; do
        case $1 in
            # Manual hostname override. Userful if hostname is stupid but immutable.
            -h | --hostname ) 
                shift
                CUSTOM_HOSTNAME=$1
                ;;
        esac
        shift
    done
    # We don't set PS1 in this file, only return a valid one.
    out=''

    # Chroot detection, will prepend the name of the chroot while showing hostname.
    out=$out"${debian_chroot:+($debian_chroot)}"    
    # Use system hostname if custom hostname is not set.
    
    #out=$out"\u${RESTORE}@"
    #out='\[${YELLOW}\]\u\[${Normal}\]@\[${NORMAL}\]'
    out=$out'\[$CYAN\]\u\[$RESTORE\]'
    out=$out'@'
    #out=$out'\[$LBLUE\]\h\[$RESTORE\]'

    # If no custom hostname passed, take the default.
    if [ ! $CUSTOM_HOSTNAME ]; then
        CUSTOM_HOSTNAME='\h'
    fi
    out=$out'\[$LBLUE\]'
    out=$out"$CUSTOM_HOSTNAME"
    out=$out'\[$RESTORE\]'

    # Current working directory.
    out=$out':'
    out=$out'\[$YELLOW\]\w\[$RESTORE\]'

    out=$out'['
    out=$out'\[$RED\]'
    out=$out"\$(date +%s)"
    out=$out'\[$RESTORE\]'
    out=$out']'

    # $/# prompt terminus.
    out=$out"\$"

    # Extra space at the end.
    out=$out" "

    echo "$out"
    return 0
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
