---
description: "Use when redesigning the Dashboard page into a premium, clear, and visually captivating static UI (no animations), with a professional company header."
name: "Redesign Dashboard Premium"
argument-hint: "Company name, tagline, contact details, preferred color direction"
agent: "agent"
---
Redesign the Dashboard page to a premium UI/UX experience that feels clear, elegant, and visually captivating without using animations.

Default style direction:
- Modern Bold (high-clarity layout, confident visual contrast, premium static look).

Default header details to use in the top professional header:
- Company name: شركه المشد لتجاره الحدايد والبويات والديكور
- Phone: 01017149438 - 01550819097
- Address: اول ميت حبيش عماره المشد

User direction:
دلوقتي انت افضل مصمم UI/UX في العالم عايزك تعيد اصميم صفحة الداشبورد بطريقة فهمة وجذابة ساحرة بدون انميشن.
مع اضافة هيدر احترافي لكتابة اسم الشركة وتفاصيلها في أعلي الصفحة.

Execution requirements:
- Keep existing business data and metrics intact; redesign presentation only unless explicitly asked.
- Preserve current app architecture, routing, and state-management patterns.
- Use and respect the application's existing visual identity (brand language, theme direction, and component style consistency).
- Respect existing localization usage and do not hardcode untranslated UI text.
- Build a strong visual hierarchy with a professional top header area for:
  - Company name
  - Company subtitle/tagline
  - Optional contact line (phone, address, tax/commercial note)
- The dashboard body must be easy to scan quickly:
  - Distinct KPI cards
  - Clear section grouping
  - Balanced spacing and readable typography
- No animations and no motion dependencies.

Visual direction constraints:
- Avoid generic or boilerplate layout.
- Enforce a Modern Bold visual language across spacing, hierarchy, and card treatment.
- Use a deliberate color system with CSS-like design tokens translated into Flutter theme values or local constants.
- Avoid default-looking typography choices and weak contrast.
- Ensure desktop-first quality and solid behavior on smaller widths.

Code quality constraints:
- Reuse shared UI components where possible.
- Keep widgets modular and readable.
- Do not introduce unrelated refactors.
- Run analyzer after edits and fix issues introduced by the redesign.

Output format:
1. Brief design intent summary (3-6 lines).
2. Exact files changed.
3. Implemented Flutter code changes.
4. Short verification note (analyzer result + responsive behavior).

If company branding details are not provided at runtime, use the default header details listed above.
