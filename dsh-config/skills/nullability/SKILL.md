---
name: nullability
description: >-
  Use when writing or reviewing a method that may have nothing to return, when
  choosing between Optional and null, or when tempted to substitute a fallback
  value for a missing one. Enforces: model absence as absence (Optional at the
  boundary that discovers it), never fabricate a stand-in value, and keep the
  null-vs-Optional choice consistent with the surrounding call chain. Triggers
  on: "return null", "Optional", "orElse", "nullable", "fallback", "default
  value", "not found", "missing", "@Nullable", NPE fixes.
---

# Nullability

Absence is a real outcome. The job is to represent it honestly and let the
caller decide — not to paper over it with a substitute value.

## Rules

1. **Never fabricate a fallback for a missing identifier.** If the lookup key
   isn't there, the answer is "not found", not "here's a different key that
   might accidentally match". A fallback turns a clean "no data" into a wrong
   answer from a downstream system.
2. **Return `Optional<T>` from the method that discovers the absence** — the
   lookup, the mapper, the builder. That's where the compiler can force the
   caller to deal with it.
3. **Don't return `Optional` from getters, fields, records, or collections.**
   Empty collection, not `Optional<List>`; a nullable field stays a field.
4. **Unwrap at the boundary, once.** If the caller's own contract is nullable
   (an existing `resolve()` that already returns `null`), unwrap with
   `.map(...).orElse(null)` there rather than propagating `Optional` up through
   a chain that isn't built for it.
5. **Match the surrounding chain.** A lone `Optional` in a layer where every
   sibling returns a bare value buys nothing and costs consistency. Either
   convert the layer or unwrap at its edge.
6. **`null` means absent, and nothing else.** Never overload it as "error",
   "not yet computed", or "use the default" — throw or model those explicitly.

## The technique: push the decision up, don't invent data

When a lookup finds nothing, resist filling the hole. Ask: *does the caller
have information I don't about what "missing" should mean?* Usually yes — one
caller wants to block, another wants to skip, a third wants to retry. Hand them
the emptiness.

## Example

A status mapper that couldn't find the provider's reference, so it invented one:

```java
public SqbStatusCommand build(UUID p2pTransactionId, PaymentOperationType operationType, UUID cardId) {
    String paymentId = sqbRepository
            .findFirstByP2pTransactionIdAndTypeOrderByIdDesc(p2pTransactionId, dbType(operationType))
            .map(P2pOperationSqbEntity::getSrn)
            .filter(StringUtils::hasText)
            .orElse(p2pTransactionId.toString());
    return new SqbStatusCommand(paymentId, resolveRbsNumber(cardId), operationType);
}
```

The `orElse` sends our own transaction id to the provider as if it were their
`srn`. The provider answers about a payment that isn't the one we asked about —
and a reversal decision gets made on that answer.

Model the absence instead:

```java
public Optional<SqbStatusCommand> build(UUID p2pTransactionId, PaymentOperationType operationType, UUID cardId) {
    return sqbRepository
            .findFirstByP2pTransactionIdAndTypeOrderByIdDesc(p2pTransactionId, dbType(operationType))
            .map(P2pOperationSqbEntity::getSrn)
            .filter(StringUtils::hasText)
            .map(srn -> new SqbStatusCommand(srn, resolveRbsNumber(cardId), operationType));
}
```

and unwrap once, at the caller whose contract is already nullable:

```java
return sqbStatusRequestMapper
        .build(p2pTransactionId, operationType, cardId)
        .map(paymentStatusService::checkSqb)
        .orElse(null);
```

No provider call happens, each caller applies its own meaning to "no leg
found", and nothing is invented.

## Checklist before returning a value that might be absent

- Am I substituting a value the caller could mistake for a real one? → Don't.
- Does the caller need to distinguish "absent" from a legitimate value? → `Optional`.
- Is this a getter, field, or collection? → not `Optional`.
- Am I introducing `Optional` into a layer where nothing else uses it? → unwrap
  at that layer's edge.

## Related

- Naming the absence rather than commenting it: `self-documenting-code`.
- Cover both branches with tests (present + absent): `tdd`.
