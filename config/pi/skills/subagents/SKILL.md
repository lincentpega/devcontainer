---
name: subagents
description: >-
  Delegate work to isolated subagents by having pi invoke itself (`pi -p`):
  parallelize independent chunks (review several areas, probe multiple
  hypotheses, implement disjoint modules, run tests) without polluting the
  main context. Quick tasks run in the foreground; long-running or parallel
  fan-out runs detached in tmux and is collected later. Pick a different model
  per subagent with --provider/--model. Use when work splits into independent
  packages, should outlive interruptions, or needs a separate context window.
compatibility: Requires the pi CLI in PATH and tmux (both present in the devbox devcontainer). `run` needs no tmux.
---

# Subagents

Spawn isolated `pi -p` sub-processes — a full pi session each (own context,
own tools, same repo access). Interface: `./scripts/subagent` (run from this
skill dir), backed by `/tmp/pi-subagents/<name>/` for logs/state.

## When to use (vs. just doing it)

Use when: work splits into independent packages (parallel reviewers on disjoint
areas, separate research probes); a job is long and should survive Ctrl+C /
parent exit; or you want isolation (exploratory/dirty work out of main context).
Don't use for a single sequential task tightly coupled to this conversation —
do it yourself.

## Commands

```bash
./scripts/subagent run    [flags] -- "task"            # synchronous, streams
./scripts/subagent start  [flags] --name review-auth -- "task"   # tmux, returns now
./scripts/subagent status [name...]                    # never blocks
./scripts/subagent wait   [--timeout S] name...        # block until done, print reports
./scripts/subagent logs   name [-n 200]
./scripts/subagent kill   name...                      # stop (logs kept)
./scripts/subagent list / prune [--all]
```

Flags (run/start): `--provider P --model M` (only when a specific model is
wanted — otherwise the subagent uses pi's defaults), `--dir DIR`, `--tools
a,b,c` / `--exclude-tools`, `--role-file F` (extra system prompt), `--plain`
(no worker role), `--at FILE` (like pi `@file`), `--timeout S` (`run`: kill;
`wait`: stop waiting). Every subagent gets a default worker role: work
autonomously, no clarifying questions — state assumptions — and finish with a
compact `## Result` report. `pi`'s stdout carries only that final report, so
logs stay clean.

## Orchestration contract (critical)

pi does not self-wake: nothing polls after a turn ends. Three execution styles:

1. **One-shot (want a single consolidated answer):** in one turn, `start` the
   jobs, then end with one blocking `wait name... --timeout N`. You block ~
   max(runtime); one model round-trip, even for N jobs.
2. **Interactive long-runs:** if jobs take minutes+, don't hog the turn — say
   "started review-* in tmux; reply *collect* when you want results". The user
   re-prompts later; then you `status`, `wait`, summarize.
3. **Headless parents:** orchestrate from `pi -p "..."` — fully autonomous
   fan-out → wait → summarize in one continuous run.

Other rules: name jobs by purpose (`review-auth`, `probe-2`); give parallel
agents **disjoint scope** and a self-contained task (state cwd-relative paths,
output format); `status` before `wait`; `wait` with `--timeout` (a hang blocks
you — timeout never kills the job, `kill` does); summarize the `## Result`
sections into the conversation, don't dump raw logs; keep model diversity
cheap (`scout` on fast model, `reviewer` on strong model only if asked).

## Failures & costs

- Each subagent = one pi process: cost ~N× tokens, wall time ~max(runtime).
- Subagents inherit your privileges/config — delegate only what you'd run
  yourself.
- Exit codes: `wait` prints `[exit N]`; interrupted jobs (killed, tmux died)
  print `[interrupted]`. `run`/`wait` return 0 ok, 124 timeout, non-zero on
  job failure.
- Jobs survive parent exit (tmux daemon); collect later from any session.

See [references/pi-flags.md](references/pi-flags.md) for the full flag map and
advanced patterns (thinking budgets, tool restrictions, read-only review).
