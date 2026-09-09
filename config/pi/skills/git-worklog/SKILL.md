---
name: git-worklog
description: >
  Build a confirmation-only daily worklog preview from Git commits and current
  dirty worktrees across Development projects.
  Use when the user asks what they worked on, requests a Git-based worklog, or
  wants a retroactive daily worklog draft.
  Triggers on: "what did I work on", "worklog", "daily worklog", "worklog for
  yesterday", "что я делал", "собери ворклог".
  Do not use to post time entries.
---

# Git Worklog

Build a worklog preview from Git evidence. Git is the primary source and the workflow must work without agent hooks or session logs.

## Scan

Use the requested `YYYY-MM-DD` date, defaulting to today. Resolve the scanner in this order:

1. `$WORKLOG_GIT_SCAN`, if it points to an executable;
2. `~/worklog/bin/git-scan`;
3. `~/Development/worklog/bin/git-scan`.

Run the resolved scanner with `--date`. Add `--root` and repeatable `--email` arguments only when the user supplies them or the default Git identities miss known work. Read its JSON from stdout; do not modify repositories.

The scanner already uses logical repositories (`git-common-dir`), all registered worktrees, author-date filtering, reflog-aware discovery, and stable patch-ID deduplication. Treat one returned commit object as one independent commit signal even when its `shas` array contains several copies.

## Build the preview

Create one candidate work item for every scanner item with commits or dirty files, keyed by its `key` (`<common_git_dir>@<branch>`). Combine sources by union: evidence from one source is sufficient to retain the work item.

For each work item, derive a concise description from commit subjects and changed-file paths. Keep facts separate from inference. `unattributed` means Git cannot reliably select one branch; preserve its candidate branches and ask the user to resolve it before mapping or posting it.

For ticket resolution, use this order when the user requests a tracker-ready preview:

1. `<repository>/.claude/worklog-map.json` branch mapping, when present;
2. an unambiguous tracker match derived from the branch slug;
3. a ticket reference in a commit subject;
4. ask the user.

Do not infer an issue ID solely from a branch name. Treat `development` and `production` as release/integration activity unless a local mapping says otherwise.

When allocating the configured daily target (8 hours unless the user gives another target), use evidence weights: one per deduplicated commit and one per dirty-file worktree snapshot. Cap a single work item at 50% of the target. State the target stretch explicitly. If there is no evidence, ask the user rather than inventing activity.

Present a preview with work item, ticket status, proposed duration if requested, description, evidence, and stretch indicator. Never post tracker entries or update a worklog map without explicit user confirmation.

## Evidence limits

Commits are retrospective evidence. Dirty files are only a snapshot of the day the scanner runs: they may predate today or result from tools, so label them as uncommitted/current and do not use them as proof of work on historical dates.

If the scanner is unavailable, report the missing path and stop. Do not replace it with a shallow per-directory `git log` scan: that loses worktrees, reflog-only commits, and patch-ID deduplication.
