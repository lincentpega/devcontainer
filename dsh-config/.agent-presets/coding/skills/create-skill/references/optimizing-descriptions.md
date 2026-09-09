# Optimizing skill descriptions

How to write a `description` that triggers at the right times. Distilled from
https://agentskills.io/skill-creation/optimizing-descriptions.

## Why descriptions matter

At startup agents load only each skill's `name` and `description`. The
description carries the whole burden of triggering: if it doesn't convey when
the skill is useful, the agent never reads the rest of SKILL.md.

Nuance: agents typically consult skills only for tasks needing knowledge or
capabilities beyond basic tools. A one-step "read this PDF" may not trigger a
PDF skill even with a perfect description; unfamiliar APIs, domain workflows,
and uncommon formats are where a well-written description makes the difference.

## Writing principles

- **Imperative phrasing.** "Use this skill when..." rather than "This skill
  does..." — the agent is deciding whether to act, so tell it when to act.
- **Focus on user intent, not implementation.** Describe what the user is
  trying to achieve; the agent matches against what the user asked.
- **Err on the side of pushy.** Explicitly list contexts where the skill
  applies, including cases where the user doesn't name the domain directly
  ("even if they don't mention 'CSV' or 'analysis'").
- **Keep it concise.** A few sentences to a short paragraph. Hard limit:
  1024 characters. (Pi-specific: descriptions are permanent context injected
  into every session, so prefer the shorter end.)
- **Include keywords** (per the spec) that help agents spot relevant tasks.

Before/after:

```yaml
description: Helps with PDFs.                                  # too vague
description: >-
  Extracts text and tables from PDF files, fills PDF forms, and merges
  multiple PDFs. Use when working with PDF documents or when the user
  mentions PDFs, forms, or document extraction.
```

## Testing triggering

Build `eval_queries.json` — ~20 realistic prompts labeled should/shouldn't
trigger (8-10 each).

- **Should-trigger:** vary phrasing (formal, casual, typos), explicitness
  (names the domain vs. "my boss wants a chart from this data file"), detail
  (terse vs. context-heavy), and complexity (single step vs. multi-step where
  the skill's part is buried). The most useful positives are ones where the
  connection isn't obvious from the query alone.
- **Should-not-trigger:** prioritize **near-misses** — queries sharing
  keywords or concepts but needing something different (e.g. an Excel-editing
  query for a CSV-analysis skill). Obviously-irrelevant queries test nothing.

Run each query 3x through your agent and compute the **trigger rate**
(fraction of runs that loaded SKILL.md). Pass threshold ~0.5.

## Avoiding overfitting

Split queries: **train (~60%)** and **validation (~40%)**, both with a mix of
positives and negatives. Keep the split fixed across iterations so you're
comparing apples to apples.

1. Evaluate the current description on both sets.
2. Fix only **train-set** failures; keep validation results out of the
   revision process.
   - Positives failing → description too narrow: broaden scope or add
     trigger contexts.
   - Negatives false-triggering → too broad: add what it does *not* do, or
     clarify the boundary with adjacent skills.
   - Don't add keywords from failed queries — that's overfitting. Address
     the general category the queries represent.
   - Stuck after several iterations → change the structure, not just the
     wording.
3. Repeat (~5 iterations max) until train passes or gains stall.
4. Pick the iteration with the best **validation** pass rate — it may not be
   the last one produced.

## Applying the result

1. Update `description` in SKILL.md frontmatter.
2. Verify it's under 1024 characters.
3. Sanity-check with a few fresh prompts; for rigor, run 5-10 new queries
   never used during optimization.
