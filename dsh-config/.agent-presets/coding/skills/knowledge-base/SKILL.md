---
name: knowledge-base
description: >-
  Use when a task depends on knowledge that isn't in the code in front of you:
  cross-service contracts, past decisions and their rationale, runbooks,
  domain terms, external specs. Consult the knowledge base at
  /workspace/knowledge before guessing, and capture durable non-code knowledge
  discovered during a task as drafts. Load for "how does X work", "why is Y
  done this way", or when you found something not obvious that should be
  remembered.
compatibility: devbox devcontainer — KB repo at /workspace/knowledge (host ~/Development/knowledge).
---

# Knowledge Base

Shared memory between the human and all agent sessions: a git repo of markdown
files at `/workspace/knowledge`. **Code, tests, and git history are the primary
knowledge base — this repo holds only the residue:** decisions + rationale,
cross-repo contracts, runbooks, domain knowledge, gotchas.

Two tiers: `inbox/` (drafts — agents write freely) and `verified` (human-
accepted truth — small, authoritative). Wrong verified knowledge is worse than
none: it stops agents from checking. Therefore promotion is human-only.

## When to consult (before you answer)

1. Read `README.md`, then `INDEX.md` to locate topics (cheap, do it first).
2. Search: `rg -l "<terms>" topics/ runbooks/ decisions/ glossary.md` —
   targeted reads over guessing or asking the human to re-explain.
3. Honor the doc: check `status` and `last_verified` frontmatter.
   - Expired/stale → say so, verify against code, propose re-verification.
   - A claim you cannot confirm from code or a cited source → flag it; do not
     silently build on it.
4. Cite what you relied on (path, optionally line) in your answer.

## Writing rules (capture, never publish)

- New durable knowledge discovered during a task → write a **draft**:
  - rough → `inbox/<topic>.md`
  - improving an existing topic → edit it, keep `status: draft`, say so.
- Frontmatter: `title`, `status: draft`, `last_verified: <today>`, `tags`.
  Derived from a binary → also `source` + `source_sha256`.
- Every factual claim that came from an artifact (code, PDF, git history)
  carries a citation: `path:line`, commit, or PDF page. Claims you can't cite
  are marked unverified or left out.
- Small, focused files: summary line first, one topic = one file.

## Never

- Promote any draft (yours or another's) to `verified`.
- Silently change facts in a `verified` doc — propose the change for review.
- Delete or rewrite content you didn't draft and weren't asked to touch.
- Put knowledge in the KB that code answers better — keep it in code.

## Ritual

At the end of a session that produced durable non-code knowledge, propose the
draft(s) and stop. Promotion happens on the host, by the human.
