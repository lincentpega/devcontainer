---
name: document-api
description: >
  Use when documenting a REST/HTTP endpoint — writing or updating an API
  description in Markdown. Produces a concise, contract-focused reference (path,
  headers, request/response tables, examples, errors). Trigger whenever the user
  asks to "document the API", "write an API description", "describe the
  endpoint", "add docs for the new endpoint", or has just implemented an endpoint
  and wants it written up — even if they don't name a specific format.
user-invocable: true
argument-hint: [ endpoint-path-or-handler ]
---

# Document a REST endpoint

Produce a Markdown API description a client developer can integrate against without reading the
source. The guiding principle is **describe the contract, not the implementation**: what the
caller sends, what they get back, what can fail, and which fields they must null-check — never
how the service computes it internally.

`assets/example-api-description.md` is a worked example in one stack. Read it for the *shape and
level of detail* to aim for, then adapt — every service is organized differently, so treat it as
an illustration, not a rigid template.

## Before writing: read the source

Documentation invented from a handler signature alone is usually wrong about the two things that
matter most — nullability and error codes. Whatever the language or framework, trace the actual
code to ground these:

- **The handler/route** — path, HTTP method, required headers, and the request/response types it
  binds. Note any cross-cutting behavior wired in (auth, idempotency, rate limiting).
- **Request validation** — whatever expresses it (validation annotations/decorators, a schema, a
  guard clause). This gives you the Required and Validation columns. Don't guess.
- **Response model + the code that builds it** — mapper, serializer, query, projection,
  ORM model. This is the source of truth for which response fields can be absent/`null`. A field
  is optional if the producing code can emit null (a conditional branch, a nullable column, an
  optional relation). State the *condition* under which it's absent, taken from the code.
- **Error definitions** — wherever status codes and error codes/messages are defined, plus any
  tests that assert them. Tests usually reveal the real codes a caller will see.

If something is ambiguous in the code, ask rather than inventing a plausible-sounding value.

## Document the contract, not internals

These distinctions came from real review feedback and generalize across services:

- **Don't expose unimplemented surface.** If an enum or parameter has values that aren't handled
  yet (they just return an error), leave them out of the documented type and the error table. A
  caller following the contract can't reach them, so listing them only confuses.
- **Drop internal mechanics from descriptions.** Internal storage formats, the name of an
  annotation/middleware, computation steps — replace with the observable contract. E.g. document
  retry-safety as "Repeating a request with the same idempotency key returns the original
  response," not by naming the framework feature that implements it.
- **State cross-cutting facts once.** If all amounts share a currency, or all timestamps are UTC,
  say it once up front rather than repeating per field.

## Structure

A solid default skeleton. Use consistent label/heading style; adapt the field list to the
endpoint.

```
# <Title>

## <Operation summary>

**Path:** `<METHOD> /path`

**Purpose:** <one sentence>.

<short overview paragraph — discriminators, variants, anything global>
<contract-level notes: idempotency/retry behavior, units, timezones>

### Headers
<table: Header | Required | Description>

### Request body
**Type:** `application/json`
<table: Parameter | Type | Required | Validation | Description>

#### Request example
```json … ```

### Response body
**Type:** `application/json`
<table: Parameter | Type | Optional | Description>

#### Response example
```json … ```

### Errors
<sentence: error envelope + status reflects class + scoping notes>
#### Error body
<table: Parameter | Type | Description>
<table: HTTP | errorCode | When>
#### Error example
```json … ```
```

**Discriminated responses.** When one endpoint returns different payload shapes selected by a
type field, document each variant in its own table (`#### type = <VARIANT>`) and give a request
and response example per variant, reusing the same ids across them. For a single-shape endpoint,
keep just one request and one response example.

## Column conventions

Request and response tables deliberately use *different* columns, because they describe different
obligations:

- **Request tables** carry **Required** and **Validation**. Required is presence (yes/no);
  Validation is the extra constraint beyond presence (e.g. `non-blank`, `positive`, `max 100`).
  These are things the *caller must satisfy*.
- **Response tables** carry **Optional** (yes/no). The caller never sends response fields, so
  "Validation" is meaningless there; what they need is which fields to null-check. Put the yes/no
  in the column and the *condition* in the description (e.g. "absent when the bank can't be
  resolved"). After the first response table, add one line — "Optional fields are `null` when
  absent." — so un-annotated fields are unambiguous.

## Enum values live in the Type column

Write enum members in the **Type** column, not the description — they are part of the type:

```
| `type` | enum [ "P2P", "SOCIAL_INSURANCE" ] | yes | | Transaction type. |
```

Not: `| `type` | enum | yes | | P2P or SOCIAL_INSURANCE |`.

## Errors

List only codes a contract-conformant caller can actually trigger. Always include the ones people
hit first and tend to forget: request-body validation failures, and the auth/header failures
enforced before the handler runs (missing/invalid credentials, missing required headers).
Document the error envelope shape once (a table of its fields) plus one concrete error example,
then a table of `HTTP | errorCode | When`. If the API uses only standard HTTP statuses without a
numeric error code, drop that column. Note user/tenant scoping where relevant ("lookups are
scoped to the caller, so another user's id resolves as not found").

## Examples are concrete

Example JSON should use realistic values (real-looking ids, masked/representative data, actual
amounts), and reuse the same ids across request and response so a reader can follow one entity
end to end. Mirror values from tests or fixtures where they exist.
You can often refer to the test data, rather than inventing new values.

## Where the file goes

Default to the repo's existing docs location (e.g. `docs/<feature>-api.md`); look for where other
API docs live and match that. If updating an existing doc, match its current heading levels and
table column order rather than reformatting.
