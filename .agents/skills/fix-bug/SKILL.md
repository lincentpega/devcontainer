---
name: fix-bug
description: >
  Use when fixing a bug, resolving a defect, or addressing unexpected behavior.
  Enforces red/green TDD: reproduce the bug with a failing test first,
  then fix the code to make the test pass.
  Triggers on: "fix bug", "fix issue", "broken", "doesn't work", "regression",
  "defect", or any request describing incorrect behavior.
user-invocable: true
argument-hint: [bug-description-or-issue-number]
---

# Bug Fix with Red/Green TDD

Every bug fix MUST be driven by a failing test that reproduces the bug. Never fix production code without first proving the bug exists through a test.

## Workflow

### Step 1: Understand the Bug

1. Read the bug report or user description carefully
2. Identify the **exact incorrect behavior** and what the **correct behavior** should be
3. Locate the relevant code — trace the execution path to understand where the defect likely is

### Step 2: RED — Reproduce with a Failing Test

1. Write a test that **exercises the exact scenario** that triggers the bug
2. The test must follow the **AAA pattern**:

```
test("describes the correct behavior that is currently broken", () => {
    // Arrange - set up the conditions that trigger the bug
    ...

    // Act - perform the action that produces the wrong result
    ...

    // Assert - assert the CORRECT/EXPECTED behavior (this will fail now)
    ...
});
```

3. **Run the test** and confirm it fails (red). Show the user the failing output
4. The failure message should clearly show the incorrect behavior:
   - Expected X but got Y
   - Expected error but none thrown
   - Expected no error but got one
5. If the test passes immediately, either:
   - The bug is not reproduced — adjust the test to match the actual failing scenario
   - The bug was already fixed — investigate and confirm with the user

### Step 3: GREEN — Fix the Bug

1. Make the **minimal change** to production code that fixes the bug
2. Do not refactor, do not clean up unrelated code, do not add features — only fix the bug
3. **Run the test again** and confirm it passes (green). Show the user the passing output
4. **Run the full related test suite** to confirm no regressions were introduced

### Step 4: Verify

1. Run all tests in the affected module/component to ensure nothing else broke
2. If the bug could manifest in similar scenarios, consider adding additional test cases
3. Summarize: what was broken, why, and what the fix was

---

## Rules

- **Never skip the red phase.** If you cannot reproduce the bug with a test, stop and tell the user:

  > "I cannot reproduce this bug with a test. Let's discuss the exact steps or conditions that trigger it before proceeding with a fix."

- **One bug, one test (minimum).** The reproduction test is non-negotiable. Additional tests for related edge cases are welcome
- **Minimal fix.** The diff for the fix should be as small as possible. Scope creep in bug fixes introduces new bugs
- **No test modifications to make them pass.** If an existing test needs to change, explain why to the user before changing it — the existing test may be documenting intended behavior
- **Follow AAA pattern** with `// Arrange`, `// Act`, `// Assert` comments in every test
- **Test isolation** — the new test must not depend on or affect other tests

---

## Database / External Service Bugs

If the bug involves a database or external data source:
- Write an **integration test** against the real data layer (not mocks)
- Reproduce the exact data conditions that trigger the bug
- Verify the fix with the same integration test

## API / Endpoint Bugs

If the bug is in an API endpoint:
- Write a test that sends the exact request that produces the wrong response
- Assert on the correct status code, response body, and headers
- Run the test to confirm red, fix, confirm green

---

## Checklist Before Completion

- [ ] Bug is understood — incorrect vs correct behavior is clear
- [ ] Failing test reproduces the exact bug (red)
- [ ] Production code fix is minimal and targeted
- [ ] Reproduction test passes after fix (green)
- [ ] Full related test suite passes (no regressions)
- [ ] Test follows AAA pattern with comments
- [ ] Test is isolated and deterministic
