# Palette's Journal - Critical UX & Accessibility Learnings

## 2025-05-18 - Responsive I/O Grid Wrapping with Tooltips
**Learning:** Dense industrial telemetry grids like `IoMatrixWidget` overflow fixed `Row` layouts when rendered on narrow viewports (e.g. mobile/iPhone XR) or narrow dashboard columns. Using `Wrap` with explicit spacing combined with `Tooltip` and `Semantics` on interactive I/O channel dots prevents layout overflow while providing screen reader accessibility and touch/mouse hover context.
**Action:** Use `Wrap` layout with interactive `Tooltip` wrappers on all multi-item status matrix widgets across Flutter industrial dashboards.
