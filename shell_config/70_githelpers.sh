# The time massaging regexes start with ^[^<]* because that ensures that they
# only operate before the first "<". That "<" will be the beginning of the
# author name, ensuring that we don't destroy anything in the commit message
# that looks like time.
#
# The log format uses } characters between each field, and `column` is later
# used to split on them. A } in the commit subject or any other field will
# break this.

LOG_HASH="%C(yellow)%h%Creset"
LOG_RELATIVE_TIME="%Cgreen(%ar)%Creset"
LOG_AUTHOR="%C(bold blue)<%an>%Creset"
LOG_REFS="%C(bold red)%d%Creset"
LOG_SUBJECT="%s"

LOG_FORMAT="$LOG_HASH}$LOG_RELATIVE_TIME}$LOG_AUTHOR}$LOG_REFS $LOG_SUBJECT"

BRANCH_PREFIX="%(HEAD)"
BRANCH_REF="%(color:red)%(color:bold)%(refname:short)%(color:reset)"
BRANCH_HASH="%(color:yellow)%(objectname:short)%(color:reset)"
BRANCH_DATE="%(color:green)(%(committerdate:relative))%(color:reset)"
BRANCH_AUTHOR="%(color:blue)%(color:bold)<%(authorname)>%(color:reset)"
BRANCH_CONTENTS="%(contents:subject)"

BRANCH_FORMAT="$BRANCH_PREFIX}$BRANCH_REF}$BRANCH_HASH}$BRANCH_DATE}$BRANCH_AUTHOR}$BRANCH_CONTENTS"

show_git_head() {
    pretty_git_log -1
    git show -p --pretty="tformat:"
}

pretty_git_log() {
    git log --graph --color=never --pretty="tformat:${LOG_FORMAT}" $* | pretty_git_format | git_page_maybe
}

pretty_git_branch() {
    git branch -v --color=always --format=${BRANCH_FORMAT} $* | pretty_git_format
}

pretty_git_branch_sorted() {
    git branch -v --format=${BRANCH_FORMAT} --sort=-committerdate $* | pretty_git_format
}

pretty_git_format() {
    # Replace (2 years ago) with (2 years)
    sed -Ee 's/(^[^<]*) ago\)/\1)/' |
    # Replace (2 years, 5 months) with (2 years)
    sed -Ee 's/(^[^<]*), [[:digit:]]+ .*months?\)/\1)/' |
    # Line columns up based on } delimiter
    column -s '}' -t
}

git_page_maybe() {
    # Page only if we're asked to.
    if [ -n "$GIT_NO_PAGER" ]; then
        cat
    else
        # Page only if needed.
        less --quit-if-one-screen --no-init --RAW-CONTROL-CHARS --chop-long-lines
    fi
}

