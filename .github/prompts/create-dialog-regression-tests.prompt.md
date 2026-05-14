---
description: "Create or update Flutter widget regression tests for dialog layout/build crashes"
name: "Create Dialog Regression Tests"
argument-hint: "Provide target page/dialog and bug type (overflow, intrinsic, setState)"
agent: "agent"
---
Create focused Flutter widget tests to prevent dialog regressions.

Input (from user argument):
- Target dialog/page
- Error type and stack trace (if available)

Primary target in this workspace:
- Purchases and Sales invoice details dialogs.

Requirements:
1. Add tests under test/features/... matching existing structure.
2. Cover at least these assertions when applicable:
- dialog opens successfully
- no exception thrown during pump/pumpAndSettle
- no overflow-related tester.takeException output
- key actions still present (close/apply buttons)
3. Keep tests deterministic and fast.
4. Reuse existing helpers/mocks in project where available.

Validation:
- Run only relevant tests first.
- Ensure no analyzer errors in new/edited test files.

Output format:
1. New/updated test files
2. Scenarios covered
3. Test run result summary
4. Remaining edge cases (if any)
