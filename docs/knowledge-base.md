# Knowledge Base

Shared external memory for you and every agent session (pi, DSH). Markdown-first, git-versioned, at `~/Development/knowledge` (`/workspace/knowledge` in devbox).

**Why:** agents forget between sessions, and you can't hold the whole domain in your head. Fewer repeated investigations — for both of you. Measured, not assumed: if evaluation shows no gain, it gets cut.

## Rules

1. **Files, not systems.** md + git. No DB, no vector store at this scale — and any upgrade must first pass the `kb-gold` eval.
2. **Code is the primary KB.** Tests + git history already hold reviewed truth. Here lives only the residue: decisions + why, cross-repo contracts, runbooks, domain/external knowledge, gotchas.
3. **Author by source.**
   - In *your head* → you write it (agent as scribe at most).
   - In *artifacts* (PDFs, code, git) → agent extracts with citations; you spot-check — seconds of review vs hours of investigation.
   - Found *during agent work* → agent writes it as a byproduct; you skim. Often the only way it gets captured at all.
4. **Two tiers.** `inbox/` — agent drafts, no gate. `verified` — human-promoted only. A wrong verified claim is worse than none: agents stop checking and build on it; you trust it when your memory fails.
5. **Verify by evidence, not memory.** Every factual claim cites its source (`path:line`, commit, PDF page). Review = tracing citations, not recall. Unverifiable claims never reach `verified`.
6. **Knowledge rots.** `status` + `last_verified` on every doc; `verified` demotes after 90 days unless re-verified against code.

## Layout

```
knowledge/
├── README.md          # what lives here, how to search
├── INDEX.md           # topic → one-liner map
├── inbox/             # agent drafts (no gate)
├── topics/<domain>/…  # canonical — one topic = one file
├── runbooks/          # procedures (for tasks, not facts)
├── decisions/         # context → decision → consequences
├── glossary.md        # terms + aliases
├── tools/             # ingest/lint scripts
└── .kb/               # manifests, freshness state
```

Seed: migrate the loose `~/Development/*.md` notes into `topics/` verbatim, structure later.

## File convention

One-sentence summary, then frontmatter:

```yaml
---
title: ...
status: draft | verified
last_verified: YYYY-MM-DD
tags: [domain, ...]
source: <original artifact>   # if converted from binary
source_sha256: ...            # detects source drift
---
```

Focused files (≤ ~150 lines — split, don't bloat); headers name sections; tables/code over prose; consistent terms (aliases → `glossary.md`).

## Binaries (PDF/docx)

Convert **once at ingestion**; the md is the artifact, originals stay on the host. `uvx markitdown` (default) or a one-off pandoc/OCR container via docker-dind. Idempotent `tools/ingest`, manifest in `.kb/`.

## Lifecycle

| Phase | Who | What |
|---|---|---|
| Consult | you / agent | INDEX → `rg` → honor status/freshness → cite |
| Capture | agent | draft into `inbox/`, or edit a topic keeping `status: draft` |
| Promote | you | host-side `git diff` → merge → `verified` |
| Decay & lint | machine | demote stale `verified`; validate frontmatter/links/duplicates |

## Teaching pi

Skill `knowledge-base` (draft: `config/pi/skills/knowledge-base/SKILL.md`) encodes the consult + write rules. Pi never publishes — drafts only, promotion is yours. Optional thin AGENTS.md pointers in project roots. Everything else (skill refinement, ingest, INDEX, migration) pi does under this contract.

## Measuring (not vibes)

- **Baseline:** log effort/outcome for 1–2 weeks with no KB.
- **Arms:** `base` (no KB) / `kb` / `kb-gold` (exact doc handed over — separates knowledge quality from retrieval).
- **Metrics:** pass rate, wall-time, cost, human interventions; paired win-rate, n ≥ 3, model pinned; your lookup time on KB-covered questions.
- **Gate:** keep only on positive delta; kill if none after ~2 months.
