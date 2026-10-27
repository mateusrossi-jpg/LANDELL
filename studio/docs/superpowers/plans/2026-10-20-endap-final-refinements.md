# ENDAP Studio - Final Product Refinements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver 4 surgical, non-disruptive refinements to ENDAP Studio (Kiosk Touch Screen Lock with PIN, Stale Telemetry Watchdog indicator, Unified `.endap` Project Backup & Restore bundle, and ESP32 Strapping Pin Hardware Safeguards) to finalize software and firmware for commercial launch.

**Architecture:** 
Extend the existing reactive services and components without modifying the core deterministic base. `TelemetrySyncService` gains receipt timestamps and stale evaluation; `OperatorKioskView` gains a PIN-guarded touch lock mode; `ExportProjectDialog` gains a unified bundle exporter/importer (`.endap` JSON structure including Ladder, GPIO tag contracts, calibrations, and Home widgets); and `ConfigurePinDialog` displays strapping pin safeguards for hardware protection.

**Tech Stack:** 
Flutter 3.x (Web & Desktop), Dart, Provider / ChangeNotifier pattern, SharedPreferences, Playwright (automated E2E verification).

**Spec:** 
Consolidated recommendations from comparative audit with OpenPLC (IEC 61131-3 determinism), ESPHome (zero-friction onboarding/failsafe), and Home Assistant (Lovelace UI & Kiosk lockdown).

## Global Constraints
- Preserve all existing 206 passing tests and 0 `flutter analyze` errors.
- Do not modify core deterministic runtime loops (`LadderRuntime`, `1.0ms` scan cycle emulation).
- Maintain responsiveness across Desktop (1440x900), Tablet/Kiosk (1024x768), and Mobile (iPhone XR 414x896).
- All changes must be backwards-compatible with existing JSON project saves.

## Review Focus
- Telemetry timeout transitioning gracefully into `isStale` without throwing exceptions or freezing UI widgets.
- Kiosk lock dialog preventing accidental escape while allowing valid PIN unlock (`1234`).
- Round-trip `.endap` export and import preserving Ladder rungs, tags, calibrations, and Home widget configurations.
- Strapping pin safeguard alerting on GPIO 0, 2, 12, 15 without breaking valid assignments.
- Test coverage ensuring no regressions in the 206 unit/widget tests.

---

### Task 1: Stale Telemetry Watchdog in TelemetrySyncService & Home Widgets

**Files:**
- Modify: `lib/ladder/ui/editor/telemetry_sync_service.dart`
- Modify: `lib/home/renderers/home_widget_renderer.dart`
- Test: `test/telemetry_stale_watchdog_test.dart`

**Steps:**
- [ ] Write failing test in `test/telemetry_stale_watchdog_test.dart` verifying `isStale` becomes true after telemetry inactivity timeout (> 2500ms).
- [ ] Run test to verify it fails (`flutter test test/telemetry_stale_watchdog_test.dart`).
- [ ] In `TelemetrySyncService`, add `DateTime? _lastTelemetryReceived`, `DateTime? get lastTelemetryReceived`, and `bool get isStale`. Update `_lastTelemetryReceived = DateTime.now()` in `processIoMapJson` and `processPveJson`.
- [ ] In `HomeWidgetRenderer`, read `TelemetrySyncService.instance.isStale` and render a subtle `[OFFLINE / STALE]` indicator banner over widgets when stale, indicating data freshness to the operator.
- [ ] Re-run test to verify it passes.

---

### Task 2: Touch Kiosk Lock Mode with PIN in OperatorKioskView

**Files:**
- Modify: `lib/core/ui/personas/operator_kiosk_view.dart`
- Test: `test/operator_kiosk_lock_test.dart`

**Steps:**
- [ ] Write failing test in `test/operator_kiosk_lock_test.dart` verifying that locking the kiosk hides navigation/settings and requires the correct PIN (`1234`) to unlock.
- [ ] Run test to verify it fails (`flutter test test/operator_kiosk_lock_test.dart`).
- [ ] In `OperatorKioskView`, add `bool _isKioskLocked = false` state and a lock button in the header (`Icons.lock_open` -> `Icons.lock`).
- [ ] When locked, display a prominent locked badge and disable navigation out of the view.
- [ ] Implement `_showPinUnlockDialog()` with an industrial numeric keypad for 4-digit PIN verification (`1234` default).
- [ ] Re-run test to verify it passes.

---

### Task 3: Unified `.endap` Project Backup & Restoration Bundle

**Files:**
- Modify: `lib/core/ui/widgets/export_project_dialog.dart`
- Modify: `lib/models/endap_project_data.dart` (or create helper if needed)
- Modify: `lib/core/ui/studio_scaffold.dart` (to add import bundle option in drawer)
- Test: `test/endap_unified_bundle_test.dart`

**Steps:**
- [ ] Write failing test in `test/endap_unified_bundle_test.dart` testing bundle creation with `ENDAP_BUNDLE_V1` format (containing ladder, tags, calibrations, and home widgets) and round-trip restoration.
- [ ] Run test to verify it fails (`flutter test test/endap_unified_bundle_test.dart`).
- [ ] In `export_project_dialog.dart`, implement `generateUnifiedEndapBundle()` exporting the consolidated JSON structure with file extension `.endap`.
- [ ] In `StudioScaffold`, add an "Importar Pacote .endap" option in the drawer or export dialog to load a full bundle in one click.
- [ ] Re-run test to verify it passes.

---

### Task 4: ESP32 Strapping Pin Safeguards in ConfigurePinDialog

**Files:**
- Modify: `lib/features/gpio_tags/ui/widgets/configure_pin_dialog.dart`
- Test: `test/strapping_pin_safeguard_test.dart`

**Steps:**
- [ ] Write failing test in `test/strapping_pin_safeguard_test.dart` verifying that selecting digital output on GPIO 0, 2, 12, or 15 triggers a strapping pin safeguard warning in the dialog.
- [ ] Run test to verify it fails (`flutter test test/strapping_pin_safeguard_test.dart`).
- [ ] In `ConfigurePinDialog`, define `kEsp32StrappingPins = {0, 2, 12, 15}` and render an informative amber warning banner when the selected pin and function could interfere with MCU boot.
- [ ] Re-run test to verify it passes.

---

### Task 5: Complete Suite Verification, Web Build & Visual Audit

**Files:**
- All tests in `test/`
- Build outputs in `build/web/`
- Audit screenshots in `screenshots/audit/`

**Steps:**
- [ ] Run complete test suite (`flutter test`) - all 206+ tests must pass.
- [ ] Run static analysis (`flutter analyze lib/`) - 0 errors, 0 warnings.
- [ ] Compile web release (`flutter build web --no-web-resources-cdn`).
- [ ] Restart web service (`systemctl --user restart endap-studio.service`).
- [ ] Capture Playwright screenshot showing the refined features in action.
