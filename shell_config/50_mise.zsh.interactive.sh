# mise replaces nvm: one eval of a generated activation snippet instead of
# sourcing ~1000 lines of nvm.sh on every shell start. It covers node and
# python both, which is why Poetry is gone too.
#
# The activation is shell-specific, so this slot holds one file per shell rather
# than one file that re-derives the shell at runtime - the filename tag is the
# only shell predicate in this repo. Absent mise, the block is a no-op and the
# shell starts silently: a machine without it is not broken, just unmanaged.
if command -v mise >/dev/null; then
    eval "$(mise activate zsh)"
fi
