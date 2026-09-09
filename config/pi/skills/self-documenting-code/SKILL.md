---
name: self-documenting-code
description: >-
  Use when writing, refactoring, or reviewing code in this project — and always
  before adding a comment or Javadoc. Enforces self-documenting code: express
  intent through names, types, and small functions instead of comments. Avoid
  Javadoc where possible; avoid inline comments at all cost. Add a comment only
  when a specific situation needs handling that is genuinely impossible to make
  clear from the code itself.
---

# Self-documenting code

Code should explain itself through names and structure. A comment is a signal
that the code failed to — so first try to fix the code, not annotate it.

## Rules

1. **Avoid inline comments at all cost.** Before writing one, extract the thing
   it explains into a well-named method, variable, or type.
2. **Avoid Javadoc where possible.** A precise class/method name and typed
   signature usually say more than prose. Do not restate the signature in words.
3. **Comment only for the genuinely non-obvious** — a fact that cannot be
   encoded in a name and would surprise a competent reader: a workaround for an
   external system's quirk, a deliberate deviation, a subtle ordering/timing
   requirement. If a name *can* carry the meaning, a name must.
4. **Never leave a comment that restates the code**, narrates steps
   (`// Step 3: ...`), or marks sections. Delete these on sight.

## The technique: name, don't annotate

When you're about to write a comment explaining *what a condition/block means*,
extract it and let the name be the explanation.

Ask: "Could a reader understand this without the comment if I renamed
something?" If yes, rename; drop the comment.

## Example

A guard clause annotated with a comment:

```java
if (externalRef == null || externalRef.isBlank()) {
    // Payment never reached a provider (still INITIATED, or failed before the charge).
    return null;
}
```

The comment is doing the naming's job. Extract a predicate:

```java
if (!hasReachedProvider(payment)) {
    return null;
}

// elsewhere
private static boolean hasReachedProvider(InsurancePaymentEntity payment) {
    return StringUtils.hasText(payment.getExternalRef());
}
```

The condition now reads as intent and the comment is gone.

## When a comment IS justified

Keep it short, and only for what the code cannot say. For example, a value that
must match an external system's identifier for a non-obvious reason:

```java
// The ext sent to Uzcard is the p2pTransactionId; Uzcard's refNum is
// processing-assigned and unknown here.
return new UzcardStatusCommand(null, p2pTransactionId.toString(), operationType);
```

That fact lives in another system, so no local name can carry it — this is the
bar a comment must clear.
