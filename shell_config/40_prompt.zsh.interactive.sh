# zsh half of slot 40. Same shape as the bash prompt - user@host:path{branch}$ -
# built from zsh prompt escapes (%n %m %F{} %f %#), which bash does not
# understand, hence two files at one slot rather than one shared string.

# $(...) inside PS1 is only expanded per-prompt when PROMPT_SUBST is on.
setopt PROMPT_SUBST

# Generates a PS1 value.
gen_PS1() {
    local custom_hostname=''
    while [ "$1" != "" ]; do
        case $1 in
            # Manual hostname override. Useful if hostname is stupid but immutable.
            -h | --hostname )
                shift
                custom_hostname=$1
                ;;
        esac
        shift
    done

    # We don't set PS1 in this file, only return a valid one.
    local out=''

    # Chroot detection, will prepend the name of the chroot while showing hostname.
    out=$out"${debian_chroot:+($debian_chroot)}"

    # Username: red for root, cyan otherwise.
    if [ "$(id -u)" -eq 0 ]; then
        out=$out'%F{red}%n%f'
    else
        out=$out'%F{cyan}%n%f'
    fi

    # Hostname, system unless overridden.
    out=$out'@%F{blue}'
    if [ -n "$custom_hostname" ]; then
        out=$out"$custom_hostname"
    else
        out=$out'%m'
    fi
    out=$out'%f'

    # Current working directory.
    out=$out':%F{yellow}$(get_char_limited_path)%f'

    # Current git branch, if any.
    out=$out'%F{white}$(git_branch_prompt)%f'

    # %# is # for root and % for everyone else, plus a space.
    out=$out'%# '

    echo "$out"
    return 0
}

# Not exported: PS1 is per-shell, and exporting it leaks the escape sequences
# into every child process's environment.
PS1=$(gen_PS1)
