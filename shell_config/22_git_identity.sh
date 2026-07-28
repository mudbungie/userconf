# Identity as environment, not just config.
#
# `user.email` in the global config is only a *default*: one `git config
# user.email ...` inside any clone silently overrides it for that clone, and
# that accident is exactly what this exists to make impossible. Exported
# GIT_AUTHOR_* / GIT_COMMITTER_* outrank every config file git reads, including
# the repo's own .git/config, so a wrong identity cannot be configured into
# existence - only passed explicitly on the command line, where githooks-global
# catches it.
#
# It does not fight the cases where a foreign author is correct: cherry-pick,
# rebase and am all set GIT_AUTHOR_* themselves for the commit they replay, so
# the original author survives (measured, not assumed).
#
# The value stays machine-local (D3). It is read back out of git, whose global
# config includes ~/.gitconfig_local, so this tracked file ships the rule and
# never the name.

_orb_export_git_identity() {
    local name email
    name=$(git config --global user.name 2>/dev/null)
    email=$(git config --global user.email 2>/dev/null)

    # Nothing to enforce until the machine has an identity. deploy.sh already
    # warns about that; a shell that refuses to start is not an improvement.
    [ -n "$name" ] && [ -n "$email" ] || return 0

    export GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email"
    export GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email"
}

_orb_export_git_identity
unset -f _orb_export_git_identity
