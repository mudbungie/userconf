
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
    if [[ $(id -u) -eq 0 ]]; then
        out=$out'\[$LRED\]\u\[$RESTORE\]'
    else
        out=$out'\[$CYAN\]\u\[$RESTORE\]'
    fi
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
    out=$out'\[$YELLOW\]'
    out=$out'$(get_char_limited_path)'
    out=$out'\[$RESTORE\]'

    out=$out'['
    out=$out'\[$RED\]'
    out=$out"\$(date +%s)"
    out=$out'\[$RESTORE\]'
    out=$out']'

    # show the current git branch
    out=$out'\[$LIGHTGRAY\]'
    out=$out'{'
    out=$out'$(git branch --show-current 2>/dev/null)'
    out=$out'}'
    out=$out'\[$RESTORE\]'

    # $/# prompt terminus.
    if [ $(id -u) -eq 0 ] ; then
        out=$out'#'
    else
        out=$out'$'
    fi

    # Extra space at the end.
    out=$out" "

    echo "$out"
    return 0
}

export PS1=$(gen_PS1)