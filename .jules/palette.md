# Palette's Journal - Critical UX & Accessibility Learnings

## 2025-05-18 - Responsive I/O Grid Wrapping with Tooltips
**Learning:** Dense industrial telemetry grids like `IoMatrixWidget` overflow fixed `Row` layouts when rendered on narrow viewports (e.g. mobile/iPhone XR) or narrow dashboard columns. Using `Wrap` with explicit spacing combined with `Tooltip` and `Semantics` on interactive I/O channel dots prevents layout overflow while providing screen reader accessibility and touch/mouse hover context.
**Action:** Use `Wrap` layout with interactive `Tooltip` wrappers on all multi-item status matrix widgets across Flutter industrial dashboards.

## 2025-05-19 - Ladder Logic Toolbox Tooltips & Screen Reader Semantics
**Learning:** Industrial control symbols abbreviated with short technical acronyms (NO, NC, TON, CTU, PID, EQU, LES) lack clarity for new operators and are opaque to screen readers when rendered purely as text or custom painter icons. Wrapping toolbox action elements with explicit `Tooltip` and `Semantics(button: true, label: description)` provides hover guidance and accessibility without altering workspace footprint.
**Action:** Always wrap symbol/abbreviation action buttons in industrial toolbars with both `Tooltip` for visual hover and `Semantics` for accessibility.
