---
name: tdd
description: >
  Use when implementing new functionality, features, or components.
  Enforces red/green TDD with AAA (Arrange-Act-Assert) pattern.
  Triggers on: "implement", "add feature", "create endpoint", "build component",
  or any request to write new production code.
user-invocable: true
argument-hint: [description-of-feature]
---

# Red/Green TDD with AAA Pattern

You MUST follow this strict test-driven development workflow. Never write production code before its corresponding failing test.

## Workflow: Red -> Green -> Refactor

### Phase 1: RED (Write Failing Tests First)

Before writing ANY production code, write the **complete test suite** for the component/feature.

1. **Analyze the requirement** and identify all behaviors to test
2. **Write all tests first** — they MUST fail (red) because the production code does not exist yet
3. **Run the tests** and confirm they fail. Show the user the failing output
4. If tests pass before production code exists, the tests are wrong — fix them

### Phase 2: GREEN (Implement Production Code)

1. Write the **minimum production code** to make the failing tests pass
2. Complete the Arrange sections of tests if they need real values from the implementation (e.g., actual response shapes, IDs)
3. **Run the tests again** and confirm they all pass (green). Show the user the passing output
4. If any test still fails, fix the production code (not the test) until green

### Phase 3: REFACTOR (Clean Up)

1. Look for duplication or unnecessary complexity in both test and production code
2. Refactor while keeping tests green
3. Run tests after refactoring to confirm nothing broke

---

## AAA Pattern (Arrange-Act-Assert)

Every test MUST follow this structure with clear visual separation:

```
test("descriptive name of the behavior under test", () => {
    // Arrange - set up preconditions and inputs
    ...

    // Act - execute the behavior being tested
    ...

    // Assert - verify the expected outcome
    ...
});
```

Rules:
- Each section must be clearly commented with `// Arrange`, `// Act`, `// Assert`
- **One Act per test** — if you need multiple Acts, split into separate tests
- Keep Arrange minimal — only what this specific test needs
- Assert on behavior/outcome, not implementation details

---

## Test Isolation

Each test MUST be fully independent:

- **No shared mutable state** between tests. Each test sets up its own data
- **No test ordering dependencies** — any test must pass when run alone
- Use `beforeEach` / setup methods to reset state, never rely on `afterAll` side effects
- Each test gets its own instances of dependencies (fresh mocks, fresh fixtures)
- If a database is involved, each test operates on its own data or uses transactions that roll back

---

## Maintainability

Tests must be **easy to read and change**:

- Test names describe the behavior, not the implementation: `"returns 404 when user not found"` not `"test getUserById"`
- No conditional logic (`if`, `switch`, loops) inside tests. If you feel the need for logic in a test, **stop and notify the user**:

  > "This test requires conditional logic, which signals the production code may need refactoring to be more testable. Let's discuss the design before proceeding."

- Use factory functions or builders for complex test data, not inline object literals repeated across tests
- Prefer explicit values over random/generated data — tests must be deterministic
- Keep tests flat — avoid deep nesting of describe blocks (max 2 levels)

---

## Test Coverage Rules

### Component-Level Tests
When implementing any component or module, write tests covering:
- Happy path (expected inputs produce expected outputs)
- Edge cases (empty inputs, boundary values, null/undefined)
- Error cases (invalid inputs, expected failures)

### API/Endpoint Tests
If the feature exposes an endpoint or public interface that external clients interact with:
- Write integration/contract tests for each endpoint
- Test request validation (missing fields, wrong types)
- Test authentication/authorization if applicable
- Test response shape and status codes

### Database/External Data Source Tests
If the feature involves a database or external data source:
- Write **integration tests** for the repository/data-access layer against a real database (not mocks)
- Test CRUD operations with actual queries
- Test constraint violations, unique conflicts, not-found cases
- Use test database or containers, with proper setup/teardown

---

## Checklist Before Completion

- [ ] All tests were written BEFORE production code
- [ ] All tests failed (red) before implementation
- [ ] All tests pass (green) after implementation
- [ ] Every test follows AAA pattern with comments
- [ ] No test depends on another test's state
- [ ] No conditional logic in test code
- [ ] Repository layer has integration tests if a database is involved
- [ ] Endpoints have contract tests if externally consumed
