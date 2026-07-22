# Keep doing it until it works, but not forever: at most ORB_RETRY_MAX
# attempts, with exponential backoff between them.
function retry {
    local max=${ORB_RETRY_MAX:-5} delay=1 attempt=1
    until "$@"; do
        if [ "$attempt" -ge "$max" ]; then
            echo "retry: giving up on '$*' after $max attempts" >&2
            return 1
        fi
        sleep "$delay"
        delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
}

# pipe it into jq and back out
function rectify_json {
    if ! command -v jq >/dev/null; then
        echo "jq not installed"
        return 1
    fi
    if ! command -v sponge >/dev/null; then
        echo "sponge not installed"
        return 2
    fi
    if [[ $(jq . $1) ]]; then
        jq . $1 |sponge $1
    fi
}

# Non-clobbering path addition. Membership is tested on whole ':'-delimited
# segments, so neither substrings nor regex metacharacters can false-positive.
function in_path {
    case ":$PATH:" in
        *":$1:"*) return 0 ;;
        *) return 1 ;;
    esac
}

function add_to_path {
    in_path "$1" || export PATH="$PATH:$1"
}

function prepend_to_path {
    in_path "$1" || export PATH="$1:$PATH"
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

# Branch name in braces, or nothing. One git fork per prompt, not two: empty
# output covers "not a repo" and "detached HEAD" alike.
function git_branch_prompt {
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    [ -n "$branch" ] && echo "{$branch}"
    return 0
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

function mac_compliant_inline_sed {
    # BSD sed requires an explicit (here empty) backup suffix argument to -i;
    # GNU sed requires it to be absent. Neither leaves a .bak behind.
    if [ "$(uname)" = Darwin ]; then
        sed -i '' "$1" "$2"
    else
        sed -i "$1" "$2"
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
    [ -f "$1" ] && source "$1" || true
}

function is_git_repo {
    git rev-parse --is-inside-work-tree &>/dev/null
    return $?
}

