---
name: conventional-commits
description: >-
  Use when writing or rewriting git commit messages. Covers git commit,
  --amend, and git rebase -i rewording. Load whenever the user commits or
  wants to commit anything even if they don't mention the format.
---

# Conventional Commits

Write every commit message in Conventional Commits format:

```
<type>(<scope>): <subject>
```

## Types

| Type | Use for |
| --- | --- |
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that isn't a fix or feature |
| `perf` | Performance improvement |
| `test` | Adding or fixing tests |
| `build` | Build system or dependencies |
| `ci` | CI configuration |
| `style` | Formatting; no behavior change |
| `chore` | Maintenance and tooling |
| `revert` | Reverting a previous commit |

## Rules

- Scope only when it adds info: `fix(auth): ...`, not `fix(): ...`
- Imperative mood subject: `add`, not `added`/`adds`
- Lowercase subject, no trailing period, ≤ 72 chars
- Breaking change: add `!` after scope, e.g. `feat(api)!: ...`, or a `BREAKING CHANGE:` footer line

## Examples

```
feat: add user login flow
fix(auth): handle expired tokens
feat(api)!: change response format
docs: update README
```

## Rewriting existing messages

- Latest commit: `git commit --amend -m "<message>"`
- Older commits: `git rebase -i` and reword each
- Never rewrite pushed history without explicit user approval

## Validate before finalizing

Check every message before committing:

- [ ] Type is from the table (`revert` for reverts)
- [ ] Scope only when it adds info
- [ ] Imperative, lowercase subject, no trailing period
- [ ] Subject ≤ 72 chars
- [ ] Breaking changes marked with `!` or a `BREAKING CHANGE:` footer

## Gotchas

- `BREAKING CHANGE:` footer needs a blank line and description after it
- `git commit --fixup=<sha>` / `--squash=<sha>` + `git rebase -i --autosquash`
  keeps fixup history tidy
