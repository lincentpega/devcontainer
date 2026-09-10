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

Repos live under `$BARAKA_SERVICES_ROOT/<repo>` (main checkout, usually on
`development`). `BARAKA_SERVICES_ROOT` defaults to `~/Development/baraka-services`; set it
when the layout differs — in the devcontainer the repos sit in `/home/dev/workspace`, so run
the script with `BARAKA_SERVICES_ROOT=/home/dev/workspace`. All worktrees go in the shared
sibling directory:

```
$BARAKA_SERVICES_ROOT/worktrees/<repo>-<slug>
```

Never nest a worktree inside another repo's checkout, and never create one in `/tmp`.

## Branch naming

**Use the `name-branch` skill to pick the branch name** — invoke it before running
`git worktree add`. It owns the naming rules; do not improvise a name here.

The short version: `<type>/<short-kebab-slug>` (`fix/social-insurance-circuit-breaker`),
and one task spanning several repos uses the same branch name in every repo.

## Directory naming

The worktree directory is `<repo>-<slug-with-type-flattened>` — replace `/` with `-`:

```
branch  fix/social-insurance-circuit-breaker
dir     worktrees/corebanking-java-fix-social-insurance-circuit-breaker
```

## Base branch

Always `origin/production`, regardless of branch type. Use a different base only when the
user names one explicitly — never ask, never infer.

Always create from the freshly fetched remote ref, never from the local checkout's HEAD.

## Upstream

A new branch must have **no upstream**. Branching off `origin/<base>` would otherwise make
git track `origin/<base>`, pointing `git status`, `git pull` and a bare `git push` at
production. The script handles this with `--no-track`; the upstream gets set by
`git push -u origin <branch>` on the first push.

## Procedure

Run the script — do not hand-write `git worktree add`:

```bash
bash <this skill's directory>/create-worktree.sh <type>/<slug> <repo> [repo...] [--base <base>]
```

Its repos root is `$BARAKA_SERVICES_ROOT` (default `~/Development/baraka-services`) — export
it before the call when the checkouts live elsewhere. It fetches the base, creates each
worktree at `$BARAKA_SERVICES_ROOT/worktrees/<repo>-<type>-<slug>` with no upstream, skips repos
where the branch or path already exists, and prints path / branch / base / commit / upstream
per repo. Relay that output; only pass `--base` when the user names a base explicitly.

## Cleanup

To undo, remove the worktree before deleting the branch:

```bash
cd "$BARAKA_SERVICES_ROOT"/<repo>
git worktree remove ../worktrees/<dir>
git branch -D <type>/<slug>
```

Never `rm -rf` a worktree directory — it leaves stale metadata in `.git/worktrees`.

## Checks

- the script already checks for an existing path or branch and skips instead of duplicating —
  if it reports a skip, reuse the worktree it names
- confirm with the user before removing a worktree that has uncommitted changes
