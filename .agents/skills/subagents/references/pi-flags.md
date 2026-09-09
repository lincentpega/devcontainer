# pi flags for subagents

How `scripts/subagent` maps to `pi -p` invocations, plus advanced levers.

## The generated invocation

```
pi [--provider P] [--model M] [--tools LIST] [--exclude-tools LIST]
   [--append-system-prompt "<worker role>"] [--no-session] -p -- <task...>
```

- `-p` / `--print`: non-interactive — processes the task and exits. stdout is
  **only the model's final answer** (tool calls are not echoed), which is what
  keeps `run.log` clean.
- `--append-system-prompt`: injects the worker role (autonomous, no
  clarifying questions, ends with `## Result`). Override/extend with
  `--role-file`; suppress with `--plain`.
- `--no-session`: default — subagent runs are ephemeral and don't pollute
  pi's session store. `--keep-session` opts out (session then lives under the
  project's `.pi/` as usual).

## Model selection

- **Omit** `--provider`/`--model` → the subagent uses pi's configured
  defaults (normally the same model the parent runs).
- `--model anthropic/claude-haiku-4-5` or a shorthand like
  `--model haiku:high` (thinking levels: off|minimal|low|medium|high|xhigh|max)
  also work — subagent takes a `--thinking`-level suffix if given.

## Tool restrictions

- `--tools read,bash,edit,write,grep,find,ls` → allowlist (only these tools
  load). For a **read-only reviewer**: `--tools read,grep,find,ls,bash` +
  task text "do not edit anything".
- `--exclude-tools <name>` → denylist instead.

## Context & files

- Subagents auto-load the same skills/config and (project) AGENTS.md as a
  normal pi run from `--dir`.
- Hand scope via the task text (paths relative to `--dir`), or pin files with
  `--at a.ts @lib/b.ts` (translated to `@abs/path` args like interactive pi).

## Orchestration under the hood

- `start`: writes `argv.b64` (NUL-separated argv incl. task), a static
  `job.sh` launcher, and spawns `tmux new-session -d -s <name>`. The launcher
  runs pi → `run.log`, then writes `exit.code`.
- `wait`: polls `exit.code` presence / session liveness every 0.5s (no tmux
  wait-for needed) until all named jobs settle or `--timeout` (default 600s)
  elapses — timeout only stops waiting; the job keeps running.
- State lives in `/tmp/pi-subagents/<name>/`: `run.log`, `exit.code`,
  `meta`, `argv.b64`. tmpfs → wiped on container restart; jobs then read as
  `interrupted` (tmux sessions also die with the server).

## Extending

Any pi CLI flag can be threaded through by adding a case in
`parse_common()`/`build_pi_argv()` in `scripts/subagent`, e.g. `--thinking`,
`--offline`, `--approve`. For tests, `SUBAGENT_PI_BIN=/path/to/stub`
substitutes the binary and `SUBAGENT_JOB_ROOT=/tmp/x` relocates job state.
