---
name: redmine-bug
description: >
  Use when writing, filing or rewriting a bug report in Redmine (oxigen.oxinus.holdings) —
  creating the issue, drafting its description, or cleaning up an existing one.
  Produces a behavior-first ticket: Current behavior / Steps to reproduce / Expected behavior,
  and deliberately keeps the fix out of the description.
  Triggers on: "create a bug in redmine", "log this in redmine", "file a ticket",
  "оформи баг", "создай тикет", "write up this bug", "describe this bug for the tracker",
  or right after diagnosing a defect the team will need a ticket for.
---

# Redmine Bug Tickets

## The one rule that matters

**A bug ticket describes behavior, never the fix.** No root-cause walkthrough, no "changed
X to Y", no diff, no commit hash, no file list.

Why this matters: the ticket is the team's record of *what was wrong for the user*. The fix
lives in git and in the merge request, where it stays accurate as the code keeps moving. A
description that explains the fix is stale the moment someone refactors, it pre-empts QA —
who must verify observable behavior, not read your patch notes — and it turns the tracker
into a worse copy of the git log. If a reader needs the code, the MR linked to the ticket
takes them there.

Root cause is the near miss worth being precise about: it is genuinely useful and it still
does not belong in the description, because the description is what QA reads to verify the
bug and what everyone reads when triaging. Put the cause in a **comment** (`notes`) instead —
it stays available to whoever picks the ticket up, without pretending to be part of the
defect report. Same for "should we also refactor…" ideas (separate ticket) and progress
updates (comment).

## Structure

Reproduce this shape exactly — the team reads dozens of these and the bold labels are how
they skim:

```
**Current behavior:**

<what happens now, from the outside>

**Steps to reproduce:**

1. <first action>
2. <second action>
3. <where it breaks>

**Expected behavior:**

<what should happen instead>
```

`Steps to reproduce` is optional — drop it when the entry point is the whole story ("open
screen X, the list is empty"). Keep it whenever a specific service, card type, amount or
sequence is needed to hit the bug, because that is what QA replays.

Add `**Environment:**` as a final line only when it narrows things down: production vs dev,
app build number, a specific provider or service id, one affected user's PINFL or card.

## Writing each section

**Current behavior** — what a user or an API client observes: the empty screen, the 500,
the wrong amount. One or two sentences. Then, if it's a backend defect, the evidence:

- the single error line that identifies the failure — not the 200-frame stack, and not the
  application frame either: `SomeService.java:45` dates instantly and means nothing to the
  reader who has to reproduce this;
- indent it by four spaces so Redmine renders it as a code block;
- name the endpoint (`POST /api/v1/...`) rather than the Java method a user can't see.

State the blast radius when you know it — "editing an existing template is unaffected, only
adding a new one" saves the next person an hour.

**Expected behavior** — the behavior a reviewer can check, phrased as the outcome, not as
an instruction to the developer. "Saving succeeds and the payment appears in Saved payments"
— not "make the entity set createdAt".

**Subject** — the user-visible symptom in one line, no ticket-speak prefix, no file names.
Good: `Saving a Paynet payment to favorites fails with 500`. Bad: `Fix
UserPaynetFavoriteFieldEntity builder`.

Write in English, in the same plain register as the surrounding tickets, even when the
conversation is in Russian — the tracker is shared with people who don't read Russian.

## Example

For the defect "adding a Paynet payment to favorites returns 500 because the field insert
sends a null timestamp":

```
**Current behavior:**

Saving a payment to favorites always fails. POST /api/v1/card/c2b/paynet/favorite/add
returns 500 and nothing is stored — the favorite row is rolled back together with its fields.

The insert into user_paynet_favorite_field sends created_at = NULL and Postgres rejects it:

    ERROR: null value in column "created_at" of relation "user_paynet_favorite_field"
    violates not-null constraint

Editing an already saved payment is not affected — only adding a new one.

**Steps to reproduce:**

1. Open the mobile application and pay any Paynet service (gas, electricity, etc.).
2. On the success screen tap "Save".
3. Enter a template name and confirm.

**Expected behavior:**

Saving a payment to favorites succeeds, the favorite and its fields are persisted, and
created_at is populated on every field row.
```

Notice what is absent: the entity, the builder, the annotation that was inert, the branch and
the commit. All of that was known when this was written, and none of it helps the person
reproducing or verifying the bug.

## Filing it

Search before you create — a defect this visible is often already reported, and a duplicate
splits the discussion. Two or three queries over the user-facing wording and the table or
endpoint name are enough:

```
mcp__redmine__redmine_request
  path: /search.json
  params: {"q": "saved payment favorite", "issues": 1, "limit": 20}
```

Report what you found before filing: an open ticket means commenting on it instead, a closed
one is worth linking as related.

Ask for the project only when the target isn't obvious from the work; otherwise pick it and
say which you picked.

| Project | id |
|---|---|
| 2. Banking Core (corebanking-java, baraka-api) | 21 |
| 1. Platform | 20 |
| 3. Social | 22 |
| 4. Dashboard | 59 |
| 9. Admin Panel (ERP, CRM, Tech support) | 143 |
| 0. Infrastructure / DevOPS | 37 |

Tracker `Bug` is id 8. Priority defaults to `Normal` (2); raise it only when the user says
so. New issues open in status `New` (1) — leave the status and `done_ratio` alone, the board
owns them.

```
mcp__redmine__redmine_request
  path: /issues.json
  method: post
  data: {"issue": {"project_id": 21, "tracker_id": 8, "priority_id": 2,
                   "assigned_to_id": <reporter>, "subject": "...", "description": "..."}}
```

`assigned_to_id` defaults to whoever is filing — `/users/current.json` gives the id when you
don't have it. Assign it to someone else only when the user names them.

Use `\r\n` for line breaks in `description` — that's what Redmine stores, and mixing in bare
`\n` makes later diffs of the field noisy.

The project's scoring custom fields (L, V, C, U, P, D, F, B, E) come out at their default
`4`. Leave them there. They encode business priority the reporter decides — guessing numbers
puts a fabricated priority in front of everyone who sorts by them. Mention that they're at
default and offer to set them.

To rewrite an existing ticket, `put` to `/issues/<id>.json` with just the fields you're
changing. Passing `notes` alongside adds a visible comment explaining the edit, which is
worth doing when someone else is watching the issue.

## Before you file

- The description contains no fix, no root-cause walkthrough, no commit, no source file or
  line number.
- Someone who has never seen the code could follow the steps and see the bug.
- Expected behavior is checkable by QA without reading source.
- Subject names the symptom, not the code.
- The link to the created issue goes back to the user; anything you left at a default is
  named out loud.
