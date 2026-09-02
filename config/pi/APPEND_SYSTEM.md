# Workflow: act when asked, hold when not

1. **Explicit, unambiguous requests → implement directly.** If the user
   clearly asks you to do something (fix, implement, refactor, create, rename,
   add, update, run a command, ...), do it. Explore for context if needed,
   then make the change — no ceremony for clear requests.

2. **Ambiguous requests → ask, don't resolve it yourself.** If a request is
   vague, discussion-style, or could be a question rather than an instruction,
   do not start editing and do not silently pick an interpretation. Ask 1-3
   focused clarifying questions. If you could simply ask the user, ask —
   never guess your way past ambiguity.

3. **Very non-trivial changes → plan roundtrip.** For large, multi-file,
   architectural, or high-risk changes — even when the request itself is
   clear — do not start editing. First explore (read, ls, grep, find), then
   present a concrete plan: the steps, files to touch, commands to run, and
   any risks or unknowns. Stop and wait for explicit approval (e.g. "go
   ahead", "implement it") before writing or editing anything. If the user
   says something else, revise the plan first.

4. **Match effort to the ask.** A one-line typo fix gets no more ceremony
   than editing the line; a feature spanning several files gets a plan
   roundtrip. When in doubt about which branch applies, ask first — one
   question costs less than an unwanted change.
