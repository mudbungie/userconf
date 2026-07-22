# AGENTS.md — userconf

Repo-local instructions. `~/AGENTS.md` governs; this only adds what is specific
to this repo.

## Shape of the repo

- `orb_profile` is the single entrypoint sourced by every shell rc file. It
  sources `shell_config/*.sh` in filename order — the numeric prefix is the load
  order and the only ordering mechanism. Do not add ordering logic anywhere else.
- Config files are named `NN_name[.tag][.tag].sh` and are sourced only if every
  tag holds: `bash`, `zsh`, `interactive`. The vocabulary is closed; an unknown
  tag never holds. Two files may share a slot, so files at one slot must not
  depend on each other.
- `00_functions.sh` is the dependency floor; later slots may use its functions,
  it may use nothing.
- Machine-specific settings do not belong in this repo. `99_local.sh` sources
  `~/.bash_localrc`; that is where they go.
- `deploy.sh` must stay idempotent — it is re-run on every update, not just at
  bootstrap. Anything it writes into `$HOME` goes through `backup_file` first.
- The clone path `~/userconf` is hard-coded on purpose (the injected rc line is
  literal). Do not parameterize it.

## Working here

- Integration branch is **`master`**, not `main`. Remote is `origin`.
- Task tracking is `bl`. Work in the `bl claim` worktree; never edit the
  `master` checkout directly.
- `bl` addresses its store by the literal invocation directory. From inside a
  worktree, every command needs `-C /home/mark/userconf`.

## Gates

- `make test` must be green. The suite runs in a few seconds. Do not record the
  assertion count here — it changes with every ball and a stale number is worse
  than no number.
- `.githooks/pre-commit` (active after `make hooks`) enforces a 300-line ceiling
  on shell files and runs the suite. `bl close` runs this same hook as its
  delivery gate, so a red suite blocks delivery.
- `core.hooksPath` must be **absolute** (`make hooks` handles it). A relative
  value resolves against the cwd, so the `reference-transaction` auto-push hook
  silently never fires when `bl` moves `master` by plumbing from elsewhere.
- Tests must not assume the checkout is on `master` — they run inside
  `work/<id>` worktrees too. Ask git for the branch, do not hardcode it.
- shellcheck, bats and zsh are **not** installed on the primary machine. Nothing
  in the test or commit path may require them; `make lint` skips shellcheck when
  it is absent.

## Adding tests

Drop a `tests/test_<subject>.sh` file defining `test_*` functions. The runner
discovers files and functions automatically — no registration. Use `setup` /
`teardown` from `tests/lib.sh` for a temp-dir sandbox, and
`source_deploy_functions` to load `deploy.sh` without running it. Keep every
file under 300 lines.
