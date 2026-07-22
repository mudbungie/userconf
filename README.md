# userconf

Personal shell and dotfile configuration, plus the bootstrapper that installs it
onto a new machine. One clone at `~/userconf` is the single source of truth; the
files in `$HOME` are hooks into it, not copies of it (except the dotfiles, which
git cannot symlink safely across platforms and so are copied).

## Bootstrapping a machine

```sh
git clone ssh://git@github.com/mudbungie/userconf ~/userconf
cd ~/userconf
make install     # == ./deploy.sh -i
make hooks       # required once per clone (see Git hooks)
```

`deploy.sh -i` refuses to run from anywhere but `~/userconf` — the path is
hard-coded because the injected shell hook references it literally. It then:

1. creates `~/notes/daily` and `~/.local/bin`;
2. installs `vim wget curl python3 git jq` with whatever package manager exists
   (`yum`/`dnf`/`apt`/`brew`);
3. injects `. ~/userconf/orb_profile` at the top of `~/.bashrc`,
   `~/.bash_profile`, `~/.zshrc`, `~/.zprofile` and `~/.profile` (idempotently);
4. copies `dotfiles/<name>` to `~/.<name>`, backing up anything it displaces to
   `<file>.bak` (recursively, so nothing is ever squashed).

## How the shell config loads

`orb_profile` is the one entrypoint. Every rc file sources it; it guards against
double-sourcing with `ORB_PROFILE_LOADED`, then sources every
`shell_config/*.sh` in filename order. The numeric prefix *is* the load order.

| Slot | Purpose |
| --- | --- |
| `00_functions.sh` | Shared shell functions everything else depends on (`add_to_path`, `bash_colors`, `source_if_exists`, `is_git_repo`, …). Must come first. |
| `20_set_variables.sh` | Environment variables, color settings, bash completion. |
| `30_history.sh` | History size, dedup, append-on-exit behavior. |
| `40_prompt.sh` | `gen_PS1` and the prompt it installs. |
| `50_nvm.sh` | Loads nvm and its completion if present. |
| `60_aliases.sh` | Aliases and small command wrappers. |
| `70_githelpers.sh` | Git log formatting helpers (`pretty_git_format`) and git aliases' backing functions. |
| `99_local.sh` | Last word: sources `~/.bash_localrc` and `~/.local/bin/env` if they exist. Machine-specific settings go there, not in this repo. |

`dotfiles/` holds app configs copied to `~/.<name>`: `gitconfig`, `pythonrc`,
`sqliterc`, `vimrc`.

## Tests

```sh
make test
```

`tests/run_tests.sh` is a thin runner: it sources `tests/lib.sh` (assertions,
counters, per-test temp-dir sandbox) and then every `tests/test_*.sh`, calling
each `test_*` function they define. To add a subject, drop in a new
`tests/test_<subject>.sh` — the runner finds it, no registration needed.

- `test_structure.sh` — expected files exist, no stale paths, every script
  parses, core config sources cleanly.
- `test_functions.sh` — `shell_config/00_functions.sh`.
- `test_deploy.sh` — `deploy.sh` helpers and the `orb_profile` contract.
- `test_prompt.sh` — `40_prompt.sh` and `70_githelpers.sh`.

`make lint` runs `bash -n` on everything, and `shellcheck` **only if it is
installed** — shellcheck is an optional dependency and is not required for
`make test` or for committing.

## Git hooks

Hooks are version controlled in `.githooks/`. They are not active until you run
`make hooks` once per clone. That sets `core.hooksPath` to the **absolute** path
of `<main checkout>/.githooks`, not the relative `.githooks`: git resolves a
relative `core.hooksPath` against the current working directory, so a ref moved
by plumbing from outside any checkout finds no hooks at all — which is precisely
the auto-push case below. `core.hooksPath` lives in `.git/config`, which linked
worktrees share, so one `make hooks` covers them all.

**`pre-commit`** rejects a commit if any shell file (`*.sh`, `.githooks/*`,
`orb_profile`) exceeds 300 lines, or if the test suite fails. Markdown, the
`dotfiles/` payloads and config files are exempt from the line limit. Bypass
with `git commit --no-verify`.

**`reference-transaction`** auto-pushes `master` to `origin` whenever the branch
moves — merge, commit, or plumbing ref update alike. This is deliberate: the
task tracker advances `master` with `git update-ref` from outside any checkout,
so `post-commit` and `post-merge` never fire, while `reference-transaction`
fires on any ref update. It only acts on the `committed` state and only on
`refs/heads/master` (`refs/remotes/*` and `refs/heads/work/*` are ignored), it
guards against re-entry when the push updates remote-tracking refs, and the push
is detached so a missing network or ssh key warns instead of failing the ref
update. Failures are appended to `/tmp/userconf-autopush.log`.

**If you did not expect your commits to reach GitHub, this is why.** Undo it
with `git config --unset core.hooksPath`.
