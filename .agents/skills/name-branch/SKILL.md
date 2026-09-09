---
name: name-branch
description: >
  Use when naming or renaming a git branch, or when a branch name is needed as part of
  another task (creating a worktree, starting a feature, opening an MR).
  Enforces widespread OSS conventions: <type>/<short-kebab-slug>.
  Triggers on: "name the branch", "what should I call this branch", "rename branch",
  "create a branch for", "branch naming", or any request that produces a new branch.
user-invocable: true
argument-hint: [task-description]
---

# Branch Naming

Format: `<type>/<short-kebab-slug>`

| Type | Use for |
|---|---|
| `feature/` | new functionality |
| `fix/` | bug fixes, hotfixes |
| `refactor/` | no behavior change |
| `chore/` | build, deps, tooling, CI |
| `docs/` | documentation only |
| `test/` | tests only |

## Rules

- lowercase kebab-case, ASCII only — no spaces, underscores, or camelCase
- 2–5 words in the slug; describe the subject, not the action
- never repeat the type word inside the slug — `fix/otp-timeout`, not `fix/fix-otp-timeout`
- keep an issue key as a slug prefix when one exists: `fix/CB-1234-otp-timeout`
- no trailing `-fix`, `-changes`, `-wip`, or dates
- fix typos in the user's wording before they become a branch name (renaming later is costly),
  and state the correction in the reply
- one task spanning several repos uses the **same** branch name in every repo

## Examples

| Task | Branch |
|---|---|
| circuit breaker broken for social insurance payments | `fix/social-insurance-circuit-breaker` |
| add P2P transfer limits | `feat/p2p-transfer-limits` |
| bump Spring Boot to 3.3 | `chore/bump-spring-boot-3-3` |
| extract fee calculation out of the service | `refactor/extract-fee-calculation` |
| CB-2201: OTP resend returns 500 | `fix/CB-2201-otp-resend-500` |

## Related

Creating the worktree the branch lives in: use the `create-worktree` skill.
