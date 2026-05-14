---
description: "Fix Purchases details dialog render/layout errors in Flutter (overflow, intrinsic, setState during build)"
name: "Fix Purchases Details Dialog"
argument-hint: "Paste the error log and reproduction steps"
agent: "agent"
---
You are fixing a Flutter UI runtime error in the Purchases invoice details flow.

Use the user-provided argument as the primary bug report (stack trace + reproduction).

Goal:
- Make the Details action in Purchases open a stable invoice-details dialog.
- Eliminate runtime layout/build assertions without regressing behavior.

Scope:
- Focus first on lib/features/purchases/presentation/purchases_page.dart.
- If needed, inspect related files used by the dialog data flow.

Requirements:
1. Reproduce mentally from the provided error and locate the exact dialog subtree.
2. Fix the root cause (do not hide errors).
3. Keep existing actions and behaviors working (selection, shortcuts, return action, close action).
4. Avoid intrinsic-dimension conflicts in dialogs and avoid setState during build.
5. Preserve responsive behavior for narrow window sizes.

Validation checklist:
- No RenderFlex overflow in details dialog.
- No LayoutBuilder intrinsic-dimension assertion.
- No RenderShrinkWrappingViewport intrinsic assertion.
- No setState during build from dialog interactions.
- No new analyzer errors in edited files.

Output format:
1. Root cause summary (1-3 bullets)
2. Files changed
3. Exact behavioral result after fix
4. Any residual risk or follow-up test suggestions

Implementation notes:
- Prefer bounded layout in dialog content.
- Prefer Expanded/Flexible with explicit constraints for scrollable lists.
- If parent state must sync from dialog, defer safely or keep local state only.
- Keep patches minimal and targeted.
