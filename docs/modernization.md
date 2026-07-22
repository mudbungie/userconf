# userconf modernization — design

Status: living document. Edit it like code. If the implementation disagrees with
this file, one of the two is wrong; fix both in the same change. Every decision
below is numbered and names the ball that implements it, so a later ball can
amend a decision in place instead of appending a new opinion.

## The problem in one line

userconf is a 2022-era dotfile copier that claims cross-shell support it does not
have, keeps two homes for every fact it manages, and hardcodes one employer's
site policy into the core tree.

## Invariants (do not break these while modernizing)

- **`orb_profile` is the only entrypoint.** rc files contain exactly one userconf
  line: `. ~/userconf/orb_profile`. No second entrypoint gets added — that is
  interface growth.
- **The numeric prefix is the loading policy and the extension mechanism.**
  `00_functions → 20_variables → 30_history → 40_prompt → 50_<versions> →
  60_aliases → 70_githelpers → 99_local`. Adding config means adding a file at a
  slot. Nothing else may encode order.
- **The repo is the single source of truth for everything it tracks.** No fact
  lives in both the repo and `$HOME`.
- **Machine-specific policy is untracked.** If it is true on one machine, it does
  not ship to all of them.

---

## D1 — The shell question: an honest split, tagged by filename

**Decision: split. Ratified.** Implemented by bl-e129.

Dropping zsh was the other option and it is the wrong one: macOS defaults to zsh
(`chsh -s /bin/zsh` is the documented fallback in `startup_inconsistency.md`),
and a mac is the machine this package exists to tame. Supporting one shell and
hooking two is the current state, and it is the headline defect. So: support
both, honestly.

### Mechanism

One directory, one glob, order preserved. A config file is named:

    NN_name[.tag][.tag].sh

`orb_profile` sources a file only if **every** tag in its name holds right now.
The tag vocabulary is closed and small:

| tag | holds when |
|---|---|
| `bash` | `$BASH_VERSION` is set |
| `zsh` | `$ZSH_VERSION` is set |
| `interactive` | `$-` contains `i` |

No tags means always, and an **unknown tag never holds** — a typo fails closed
(file skipped) instead of leaking bash config into zsh. So
`40_prompt.bash.interactive.sh` and `40_prompt.zsh.interactive.sh` are two files
at one slot, `00_functions.sh` is shared, and adding zsh support for a slot is
one new file — severable.

*Amended by bl-e129 during implementation:* two files at one slot load in glob
order, which is not the numeric order and carries no meaning. **Files sharing a
slot must therefore be independent of one another.** This bit immediately:
`50_nvm.bash.interactive.sh` (nvm's bash-only completion) sorts *before* the
untagged `50_nvm.sh` that sets `NVM_DIR`, so it derives `${NVM_DIR:-$HOME/.nvm}`
itself rather than reading the other file's variable.

Rejected alternative: `shell_config/{shared,bash,zsh}/NN_*.sh`. Three trees
means the numeric order has to be re-merged across three globs at load time,
which is fiddly in POSIX sh and puts the ordering rule in two places (the prefix
*and* the merge code). The tag form keeps one glob and one sort.

### The detection bug this must fix

`ORB_SHELL_NAME="${ORB_SHELL_NAME:-$(basename "$SHELL")}"` is not just unused —
it is the **wrong signal**. `$SHELL` is the *login* shell from the passwd entry;
it does not change when you type `bash` inside zsh. The running shell is
identified by `$BASH_VERSION` / `$ZSH_VERSION`. Delete `ORB_SHELL_NAME` rather
than fixing it: with tag predicates, nothing needs a shell *name*.

### Interactivity

`orb_profile` is currently sourced from `~/.profile`, so prompt and history
setup run in non-interactive shells. The `interactive` tag fixes that without a
new mechanism: `30_history`, `40_prompt`, `60_aliases` carry it; `00_functions`
and `20_variables` do not.

*Amended by bl-e129:* slot 20 split rather than staying whole. The untagged
`20_set_variables.sh` (colors, PATH, `EDITOR`) is as described, but its `shopt`
calls and the bash-completion block moved to
`20_set_variables.bash.interactive.sh` — bash-only *and* pointless outside an
interactive shell. Slot 50 split the same way and for the same reason.

### rc files to hook (shrinks 5 → 3)

- `~/.bashrc` — the real bash config.
- `~/.bash_profile` — bridge only (`[ -f ~/.bashrc ] && . ~/.bashrc`). This is
  the exact macOS failure documented in `startup_inconsistency.md`: Terminal
  starts bash as a *login* shell, which never reads `.bashrc`. Because the
  bridge line is not the orb line, `inject_orb_profile` (which hardcoded the
  line it injected) became `inject_rc_line <rcfile> <line>` — one function, the
  line as an argument, no wrapper. `install_bash_config_hooks`, a dead
  backwards-compatibility alias, went with it.
- `~/.zshrc` — zsh reads it for every interactive shell, login or not.

Dropped: `~/.zprofile` (redundant with `.zshrc` for interactive use) and
`~/.profile` (the non-interactive/sh path — see D5, cost 3).

### Bug found while designing this (not in any ball yet)

`orb_profile` does `export ORB_PROFILE_LOADED=1`. Exported means **child shells
inherit it**, so a nested interactive shell trips the guard and gets *no config
at all* — no aliases, no prompt, no PATH additions. Verified:

    $ . ./orb_profile; bash -c 'echo $ORB_PROFILE_LOADED'
    1

The guard must be a plain shell variable, never exported. Assign to bl-a2a3.
Same smell in `40_prompt.sh`: `export PS1` has no reason to be exported.

---

## D2 — Deploy by symlink

**Decision: symlink. Ratified.** Implemented by bl-16c8.

Copying gives two homes for one fact, so a live edit to `~/.vimrc` is lost at the
next deploy and never reaches the repo. Symlinking makes the repo the only home,
and makes idempotence **structural**: a correct symlink is a no-op, so there is
nothing to compare and nothing to hash.

### What the reframe dissolves

- `find_best_hash_function` (the 9-hasher ladder) — delete.
- `replace_file_if_new`, `backup_file_if_new_content` — delete.
- `backup_file` — keep, but **stop the recursion**. Recursive backup exists to
  survive repeated copies; with symlinks the only backup that ever happens is
  displacing a genuine pre-existing file on first install. Rules:
  1. target is already the correct symlink → no-op;
  2. target absent → link;
  3. target is a real file or a foreign symlink → move to `<name>.bak` and link;
  4. `<name>.bak` already exists → **refuse and report**. The existing `.bak` is
     the true original and must not be overwritten. This is what kills
     `.bak.bak.bak` chains: not a smarter chain, no chain.
- `unbackup_file` — dead unless an `uninstall` verb exists. If bl-fb09's Makefile
  has no `uninstall` target, delete it; do not keep a restore half without a
  remove half.

### `orb_profile` injection stays injection

Do **not** symlink rc files. `~/.bashrc` and `~/.zshrc` are shared territory —
nvm, brew, rustup, uv and friends all append to them. Owning the file means
fighting every installer on the machine. Injection of a single grep-guarded line
is the correct asymmetry: userconf owns *its line*, not the file. Symlinks are
for files userconf owns whole (`dotfiles/*`).

---

## D3 — Contexts: add nothing. `99_local.sh` was always sufficient

**Decision: do NOT add `contexts/`. Ratified.** Documented by bl-171f, which
created nothing — see "Consequences for queued balls".

The tempting story is that `90_amazon.sh` proves we need a drop-in directory. It
proves the opposite. Look at what actually went wrong:

- Amazon path policy was **tracked in the core tree**, so it shipped to every
  machine, including ones that have never seen Apollo.
- Because it shipped everywhere it needed a runtime guard
  (`hostname -f | grep -q 'amazon.com'`), and that guard ran on every shell
  start.
- Because it ran on every shell start it could do something insane —
  `sed -i` on `~/.gitconfig` once per shell launch — and nobody noticed.

A tracked `contexts/amazon.sh` reproduces **all three** properties exactly. It
ships everywhere, it needs the same hostname guard, and it runs the same code on
the same machines. Renaming a directory does not make policy severable.

What *is* severable is the untracked hook that already exists:

    # shell_config/99_local.sh
    source_if_exists ~/.bash_localrc
    source_if_exists ~/.local/bin/env

Against the severability test — "removing a default should delete config, not
edit code" — this passes cleanly and `contexts/` does not:

| | tracked `contexts/` | untracked `~/.bash_localrc` |
|---|---|---|
| present only where it applies | no — ships everywhere | yes |
| needs a runtime guard | yes | no — presence *is* the guard |
| removing it | delete file, on every machine | delete file, on one machine |
| cost to core | a directory + a second load loop | zero, already exists |

So the answer to "where does the next 90_amazon go?" is: on the Amazon laptop, in
`~/.bash_localrc`, and nowhere else.

**Scaling objection, and why it does not force a directory.** If one machine
accumulates several independent policies, `~/.bash_localrc` grows. The user can
then write, in their own local file:

    for f in ~/.orb.d/*.sh; do . "$f"; done

The escape hatch extends itself. Core needs no change, and we do not pay for a
directory that most machines would leave empty.

**Deferred, deliberately:** `~/.bash_localrc` is a bash-era name for
shell-agnostic content. Renaming costs a manual touch on every machine for zero
behavior; leave it. Revisit only if the shell split makes it actively misleading.

---

## D4 — Toolchain policy: a rule, not a list

Implemented by bl-3059.

**A tool earns a place in the base install if it meets one of:**

1. **Bootstrap/recovery** — you cannot clone or repair this repo without it:
   `git`, `curl`, `vim`.
2. **A tracked file in this repo calls it** — `jq` (`rectify_json`, `roll`),
   `python3` (`dotfiles/pythonrc`), `column`/`less` (`70_githelpers.sh`, already
   base system).

Anything that is merely nice installs per-machine. Under this rule: `wget`
leaves (curl covers it); `ripgrep`, `fzf`, `direnv`, `tmux` do **not** enter — no
tracked file uses them, and "I like it" is a per-machine preference, which is
exactly what D3 says is untracked. If a later ball adds tracked config that calls
`fzf`, `fzf` joins the base set by rule 2, automatically. That is the point of
having a rule.

**Startup cost is a hard constraint.** No slot may spawn subprocesses at shell
start beyond a single `eval` of a version manager's activation. `50_nvm.sh`
violates this (sourcing `nvm.sh` is ~100ms+); replace it with **mise**, one
`eval "$(mise activate <shell>)"`, tagged `interactive`, keeping slot 50. mise
covers node and python, so **Poetry does not survive** — and `install_not_packages`,
which curl-pipes nvm v0.39.2 (2022) and Poetry and is never called by
`configure_user`, is deleted rather than wired.

**Related prompt cost:** `40_prompt.sh` ran `is_git_repo && git branch
--show-current` on *every prompt* — two forks per keystroke-return in any
directory. **Done by bl-e129:** `git_branch_prompt` in `00_functions.sh` makes
one `git branch --show-current` call and prints `{branch}` or nothing; empty
output covers "not a repo" and "detached HEAD" alike. Both prompt files use it,
so the collapse was not duplicated per shell.

**The agent tooling** (`dc`, `toss`, `roll`, currently uncommitted in
`60_aliases.sh`) is tracked config that depends on `claude`, `bl`, `jq` and
`gnome-terminal`. It gets its own slot (`80_agents.interactive.sh`), guarded on
`command -v bl` and `command -v claude` so a machine without them is silent. It
does not drag `claude` or `bl` into the base install — they are installed by
their own tooling. `gnome-terminal` stays hardcoded until a second desktop
actually exists (see D5, cost 6).

---

## D5 — What this does NOT solve

Attacking the design. Each item is an accepted cost with a stated reason, not an
oversight. If one of these bites, amend the decision above it.

1. **Nested dotfile targets.** `dotfiles/<name>` → `~/.<name>` is a flat
   derivation (the name *is* the path — single source of truth). Nothing under
   `~/.config/` can be managed without inventing an encoding for `/`. Accepted:
   nothing currently needs it. If something does, the honest fix is a
   `dotfiles/config/<name>` → `~/.config/<name>` second rule, not an escape
   character.
2. **Untracked local files do not sync.** By D3, machine policy lives outside
   git, so it is not backed up and drifts freely between machines. That is the
   trade for severability. If a policy is true on *every* machine, it is not
   local policy — it belongs in a numbered slot.
3. **Non-interactive shells lose userconf PATH additions.** Dropping the
   `~/.profile` hook means `ssh host 'some-tool'` no longer sees
   `~/.local/bin`. Accepted: interactive shells export PATH to their children, so
   only direct non-interactive invocations are affected, and those should name
   absolute paths. Reversible by adding a `~/.profile` hook back if it bites.
4. **zsh support ships untested.** `zsh` is not installed on the development box
   (verified: `command -v zsh` is empty), so the zsh half of D1 is written blind
   and CI cannot exercise it. Mitigation: the test runner must *skip with a
   warning*, never silently pass, and zsh support stays marked provisional in
   README until it has been run on the mac. **As shipped by bl-e129:**
   `tests/test_tags.sh::test_zsh_config_under_zsh` prints a yellow `SKIP` naming
   zsh as not installed; the tag *predicates* themselves are exercised under
   bash with a synthetic `shell_config` fixture, so what is unverified is
   narrowed to the content of the two `.zsh.` files, not the loader.
5. **No uninstall.** Symlinks and injected rc lines are left behind forever. This
   is why `unbackup_file` is on the chopping block in D2 — half an uninstall is
   worse than none.
6. **`roll` is GNOME-only.** Hardcoded `gnome-terminal`. Not parameterized,
   because a config knob with one possible value is a knob nobody sets.
7. **No secrets, no ssh-agent story.** The old notes mention an
   `scm-ssh start_agent` hook in `~/.bashrc`; it is out of scope and stays out.
   Keys and secrets are not dotfiles.
8. **No reload path.** After editing config the only refresh is `exec $SHELL` —
   the `ORB_PROFILE_LOADED` guard blocks re-sourcing in place. Accepted; a
   `reload` verb would be a new verb for a two-word workaround.
9. **We do not pick a default shell.** userconf supports bash and zsh; `chsh` is
   the user's call per machine.

---

## Consequences for queued balls

- **bl-171f (context drop-ins) — premise invalidated; done, documentation-only.**
  `contexts/` was not created. README gained a "Where machine-specific config
  goes" section: `~/.bash_localrc` via `shell_config/99_local.sh`, the
  self-extending `~/.orb.d` loop as the answer if one machine accumulates several
  policies, and a pointer back to this decision instead of a restatement of it.
  No directory, flag or load loop was added. Adding nothing was the successful
  outcome.
- **bl-e129 (shell split)** — take D1 whole: filename tags, not three trees;
  delete `ORB_SHELL_NAME` rather than making it earn its keep (the tag predicates
  replace it); hook 3 rc files, not 5.
- **bl-a2a3 (bug fixes)** — add two defects found here: the exported
  `ORB_PROFILE_LOADED` guard blanking nested shells, and `export PS1`.
- **bl-16c8 (symlink deploy)** — D2 answers its open question: rc-file injection
  stays injection. The rc-file *set* (5 → 3) is bl-e129's change, not this one;
  do not both edit `install_shell_hooks`.
- **bl-3059 (toolchain)** — D4 gives the rule; the base set lands as
  `git curl vim jq python3` (wget out), nvm → mise, Poetry out,
  `install_not_packages` deleted, agent aliases to `80_agents.interactive.sh`.
- **bl-fb09 (hygiene)** — if the Makefile grows no `uninstall` target, bl-16c8
  deletes `unbackup_file`. README must carry: the tag grammar from D1, the
  `~/.bash_localrc` mechanism from D3, and the provisional status of zsh.
- **bl-2a1a (git identity)** — unaffected in substance, but note it is the first
  real tenant of D3: identity is machine-local, untracked, and created-if-absent.
  Its `git l` / `git b` aliases hardcode
  `~/userconf/shell_config/70_githelpers.sh`; D1 keeps that path (githelpers is
  shared, so it stays `70_githelpers.sh` with no tag).
