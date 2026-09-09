---
name: plantuml-diagram
description: >
  Use when creating or editing a PlantUML diagram (.puml) — a sequence diagram of
  a flow between systems, or an activity diagram of a decision flow. Produces
  plain, low-decoration PlantUML whose source stays as readable as the rendered
  image. Triggers on: "draw a diagram", "sequence diagram", "activity diagram",
  "plantuml", "puml", "diagram this flow", "нарисуй диаграмму", or any request to
  visualize an integration, API flow, or business process.
user-invocable: true
argument-hint: "[ flow-or-feature-to-diagram ]"
---

# Write a PlantUML diagram

The source file is the artifact, not just an input to the renderer. Someone must be able to open
the `.puml`, read it top to bottom like a script, and edit a step without studying syntax. Every
rule below serves that: **plain text first, picture second**.

`assets/example-sequence.puml` is a canonical file — match its shape.

## Pick the diagram type

- **Sequence** (default) — two or more systems exchanging messages. Almost every integration,
  API, login, or payment flow is this.
- **Activity** — one actor, decision-heavy, "what happens next" logic with no meaningful
  message exchange. Use when the sequence version would be a chain of self-calls.
- Nothing else unless asked. No component/class/deployment diagrams by default.

One flow per file. If a diagram needs two `== Section ==` headers that share no participants,
split it.

## File conventions

- Name: `Title_In_Pascal_Case.puml`, placed next to sibling diagrams.
- First line: `@startuml <Human Readable Title>` — the title travels with the file, so no
  separate `title` line is needed.
- Comments use `'` and are for the author, not the reader of the image. Use them to mark phases
  of a long flow: `'Resolve recipient`.

## Participants

Declare every participant up front, in call order (left to right as they appear in the flow):

```
actor "User" as User
participant "Mobile App" as MobileApp
participant "Baraka API" as BarakaApi
```

- Human-readable label in quotes, short PascalCase alias for the body. The alias is what gets
  typed dozens of times — keep it short and stable.
- Reuse aliases and labels across diagrams in the same folder. Read a neighbouring `.puml`
  before inventing a new name for a system that already appears elsewhere.
- Colour is optional and, if used, is one inline hex per participant on the declaration line
  (`participant "Baraka API" as BarakaApi #FFDAC1`) — reuse the same colour for the same system
  across files. Never a `skinparam` block.
- Cap at ~6 participants. More than that means the flow needs splitting.

## Messages

One arrow style for requests, one for responses, always left-to-right in the source:

```
MobileApp -> BarakaApi: POST /api/user/login/send-otp
BarakaApi --> MobileApp: Return user status
```

- `->` request/call, `-->` response/return. Nothing else.
- **Never write a reverse arrow** (`<-`, `<<-`). `A <- B` reads backwards from the line it sits
  on and is the single biggest source of unreadable `.puml`. Write `B --> A`.
- Message text is what happens, in the caller's words, plus the endpoint when there is one:
  `Get account status\nGET /api/accounts/v1/check-status/{applicationId}`.
- `A -> A: ...` for internal work worth showing (`Validate OTP over stored hash`). Use it for
  state changes and decisions, not for every internal step.
- Never leave a message label empty — if the response carries nothing, say `200 OK` or drop the
  arrow.
- `\n` to wrap a long label; aim for lines under ~60 characters so the source column stays narrow.

## Control flow

- `alt` / `else` for branches. Put the condition in the header in the same language the code
  uses: `alt cardBrand == ALOQA`, `alt userStatus in ("NOT_EXISTS", "INITIAL")`.
- `break <condition>` for an error path that ends the flow. Prefer it over an `alt` whose second
  branch is the whole rest of the diagram.
- `loop <until what>` for polling and retries — the header states the exit condition.
- `group <name>` to fence a self-contained sub-flow; `== Section ==` to split phases of a long
  diagram (Login / P2P Transfer).
- Nesting depth 2 maximum. A third level means the branch deserves its own diagram.

## Notes

`note over X` / `note left of X` only for facts that cannot be an arrow: why a branch exists,
what a returned payload contains, a business rule. Two or three per diagram at most. If a note
is longer than three lines it belongs in the surrounding document, not the picture.

## Activity diagrams

```
@startuml P2P Fraud Check
start
:User enters transfer amount;
if (Status is BLOCKED?) then (yes)
  :Refuse operation;
  stop
else (no)
endif
:Execute transaction;
stop
@enduml
```

- Short imperative step labels; conditions phrased as questions with `(yes)` / `(no)` labels.
- Terminate every dead-end branch with `stop`.
- Same nesting limit: 2.

## Keep it plain — never add

- `skinparam` blocks, `!theme`, `!include` of style files, `<style>` blocks.
- `autonumber`, `hide footbox`, `skinparam responseMessageBelowArrow`, activation
  `activate`/`deactivate` bars — unless the user explicitly asks.
- Decorative stereotypes, icons, sprites, gradients, rounded-corner tweaks.
- Colour beyond the one-hex-per-participant convention above.

Decoration is only ever added on explicit request, and even then only the specific thing asked for.

## Finish

1. Verify it parses: `plantuml -checkonly <file>.puml` (or `plantuml -tpng <file>.puml` to render,
   if PlantUML is installed — `brew install plantuml`). If it is not installed, say so rather
   than claiming the diagram renders.
2. Re-read the source top to bottom as prose. If any line makes you look up syntax or trace a
   direction, rewrite it.
3. Check: no reverse arrows, no empty labels, nesting ≤ 2, ≤ ~6 participants, no `skinparam`.
