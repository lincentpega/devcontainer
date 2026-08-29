---
name: create-skill
description: >-
  How to create or modify pi skills: structure, frontmatter, and bundled-script
  conventions. Load when authoring a skill.
compatibility: pi implements the Agent Skills standard (agentskills.io).
---

# Creating Skills

Skills are self-contained capability packages the agent loads on-demand.
Pi implements the [Agent Skills standard](https://agentskills.io/specification).

## Sources of truth

- **Spec (bundled — no web fetch needed):**
  [specification.md](references/specification.md) — directory structure,
  frontmatter fields and examples, scripts/·references/·assets/ conventions,
  progressive disclosure, file references, validation.
- **Pi's skills doc** (pi-specifics — discovery, validation, examples):
  `docs/skills.md` under the pi install

Everything the spec covers lives in the reference file — don't restate it here.

## Conciseness requirements

When authoring or editing a skill, keep everything lean:

- **Be concise.** Every line of a skill is loaded context. Say things in the
  fewest words that stay unambiguous; prefer short lists over paragraphs.
- **No overly specific information.** Don't bake in details that only apply to
  one project, machine, or user (absolute paths, usernames, one-off commands,
  project-specific conventions) unless the skill's whole purpose is that
  project. Keep examples minimal and generic.
- If a detail is niche, push it to `references/` so it loads only when needed —
  not into SKILL.md.

## Pi-specific notes (not in the spec)

- **`disable-model-invocation: true`** in frontmatter hides the skill from the
  system prompt; users must invoke it explicitly via `/skill:name`.
- **Discovery:** `~/.pi/agent/skills/` (global), `.pi/skills/` (project, after
  trust), packages, settings `skills` array, `--skill` flag. Directories
  containing `SKILL.md` are discovered recursively; root `.md` files with valid
  frontmatter count as skills too. `/skill:name` forces loading; args after the
  command are appended as `User: <args>`.
- **Relative paths** in SKILL.md resolve against the skill dir — never hardcode
  absolute paths; reference files as `references/foo.md` and run scripts as
  `./scripts/foo ...`.
- **Description is permanent context:** it is injected into the system prompt
  of every session whether or not the skill is used, so keep it to 1-2 lines
  and don't restate the skill name or other skills.
- If a script needs runtime deps or auth, say so in `compatibility` and/or a
  Setup section in SKILL.md.

## Workflow tips

- Keep SKILL.md focused on usage; push depth into `references/`.
- Prefer skills over one-off scripts in random paths: skills are the portable,
  self-contained unit and (in this devcontainer) `~/.pi/agent/skills/` is a
  persistent repo mount.
- For any persistent config, prefer repo-mounted paths (e.g. `~/.pi/agent`,
  `~/.config/nvim`) so changes are versioned and survive container recreation.
- Model behavior on pi's examples: see the `brave-search` example in
  `docs/skills.md`, and skill repos like
  [badlogic/pi-skills](https://github.com/badlogic/pi-skills).
