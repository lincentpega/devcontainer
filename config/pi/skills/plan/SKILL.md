---
name: plan
description: >-
  Plan-first workflow for implementation tasks. Use when the user requests
  any non-trivial feature, fix, or refactor: explore, produce a concrete
  plan, and wait for explicit approval before writing or editing any code.
  Never implement anything unless the user explicitly says to.
---

# Plan

When this skill is active, the agent **plans only**. Do not write, edit, or
execute any code — no implementation, no scaffolding, no file creation.

## What to do

1. Read the user's request.
2. Produce a **plan**: a bullet list of concrete steps
   (files to touch, commands to run, risks to watch).
3. Stop. Ask the user for approval before doing anything else.

## What NOT to do

- Do not implement anything — code, configs, or commands — unless the user
  explicitly says so after seeing the plan.
- Do not silently expand the plan into execution.
- Do not pad the plan with fluff.

## Explicit go-ahead

Only start implementing when the user gives an explicit instruction to
proceed (e.g. "go ahead", "implement it", "yes, do it"). When they do,
implement the approved plan, and note any deviations.
