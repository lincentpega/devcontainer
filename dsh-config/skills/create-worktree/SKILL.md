---
name: create-worktree
description: >
  Use when creating git worktrees for one or more repositories, or when naming a
  branch for new work. Enforces the local worktrees/ layout and OSS branch
  naming conventions (type/short-kebab-slug).
  Triggers on: "create worktree", "create worktrees for X and Y", "new branch for",
  "make a worktree", "сделай воркtree", or any request to start isolated work on a repo.
user-invocable: true
argument-hint: "[repos] [task-description]"
---

# Create Worktrees & Name Branches

## Repo layout

Repos live under a repos root — one directory holding the checkouts plus the shared
`worktrees/` directory:

```
<root>/<repo>                           main checkout
<root>/worktrees/<repo>-<type>-<slug>   what this skill creates
```

Find the root, in this order:

1. `$BARAKA_SERVICES_ROOT`, when set
2. the current directory or its nearest ancestor holding repo checkouts
3. `$HOME/workspace`, then `~/Development/baraka-services` (host layout)

The script does this itself and prints the root it picked — no env var needed. Do
not export `BARAKA_SERVICES_ROOT` unless the user names a layout the detection
cannot see; it is only an override. Never nest a worktree inside another repo's
checkout, and never create one in `/tmp`.

## Branch naming

**Use the `name-branch` skill to pick the branch name** — invoke it before running
the script. It owns the naming rules; do not improvise a name here.

The short version: `<type>/<short-kebab-slug>` (`fix/social-insurance-circuit-breaker`),
and one task spanning several repos uses the same branch name in every repo.

## Directory naming

The worktree directory is `<repo>-<type>-<slug>` — the `/` becomes `-`:

```
branch  fix/social-insurance-circuit-breaker
dir     worktrees/corebanking-java-fix-social-insurance-circuit-breaker
```

## Base branch

`origin/production` across all repos, regardless of branch type. Pass `--base` only
when the user names a base explicitly — never ask, never infer.

Always create from the freshly fetched remote ref, never from the local checkout's
HEAD. A repo with no `production` branch (some repos are `main`-only, for example
`social-wallet-flutter`) falls back to its remote default branch, and the script
reports which base it actually used.

## Upstream

A new branch must have **no upstream**. Branching off `origin/<base>` would otherwise
make git track `origin/<base>`, pointing `git status`, `git pull` and a bare
`git push` at production. The upstream gets set by `git push -u origin <branch>` on
the first push.

## Procedure

Run the script — do not hand-write `git worktree add`:

```bash
bash <this skill's directory>/create-worktree.sh <type>/<slug> <repo> [repo...] [--base <base>]
```

Per repo it prints path / branch / base / commit / upstream, and reports `created`,
`reused`, or `skipped` with the reason. Relay that output. A branch already checked
out in another worktree is reported, not duplicated; a branch that exists only
locally gets a worktree on that branch.

## Cleanup

To undo, remove the worktree before deleting the branch:

```bash
cd "$BARAKA_SERVICES_ROOT"/<repo>
git worktree remove ../worktrees/<dir>
git branch -D <type>/<slug>
```

Never `rm -rf` a worktree directory — it leaves stale metadata in `.git/worktrees`.
Confirm with the user before removing a worktree that has uncommitted changes.

## Checks

- if the script reports a reuse or a skip, reuse the worktree it names — do not
  create a second one
- `bash create-worktree.test.sh` next to the script drives it against throwaway
  repos in a temp dir: no network, no side effects. Run it after any change to the
  script, and keep the copies of this skill in sync (`.agents/skills`,
  `dsh-config/skills`, `dsh-config/.agent-presets/coding/skills`)
