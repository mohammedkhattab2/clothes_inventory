---
description: "Use when creating or editing Flutter dialogs to avoid intrinsic-dimension and overflow crashes"
applyTo: "lib/**/*.dart"
---
When working with Flutter dialog UIs in this workspace, follow these safety rules:

1. Do not place `LayoutBuilder` directly in a way that `AlertDialog` must compute intrinsic size from it.
2. Avoid `ListView(shrinkWrap: true)` as the main body inside dialogs when parent is measuring intrinsically.
3. Ensure scrollable regions are bounded using explicit constraints and `Expanded`/`Flexible` in a max-sized column.
4. Prefer custom `Dialog` over `AlertDialog` for complex content with multiple controls and long lists.
5. Never call parent-page `setState` during a dialog build pass; keep dialog state local or defer updates safely.
6. For small windows, allow action buttons to wrap instead of forcing fixed horizontal rows.
7. After edits, verify no runtime errors for:
- RenderFlex overflow
- LayoutBuilder intrinsic dimensions assertion
- RenderShrinkWrappingViewport intrinsic assertion
- setState during build
