---
created: 2026-08-11T03:55:45.136Z
title: Flutter UI/UX polish pass — page transitions, animation coverage, button/icon tactility
area: ui
files:
  - mobile/lib/core/router/app_router.dart
  - mobile/lib/shared_widgets/primary_button.dart
  - mobile/lib/shared_widgets/secondary_button.dart
  - mobile/lib/features/sos/presentation/sos_arm_button.dart
  - mobile/lib/features/home/presentation/main_shell.dart
  - mobile/lib/features/location/presentation/member_detail_sheet.dart:133
  - mobile/lib/features/location/presentation/route_stats_sheet.dart
  - mobile/lib/features/auth/presentation/welcome_screen.dart:36
  - mobile/lib/features/sos/application/sos_controller.dart:48
  - mobile/lib/core/deep_link/deep_link_service.dart:45
---

## Problem

Captured via a `/flutter-ui` skill audit at the start of Phase 04 (Geofencing planning finished, execution not started). Not a bug list — a deliberate UX/animation/design polish pass the user wants queued for later, not implemented now. The codebase is already fairly disciplined (const-correct, theme-driven per `01-UI-SPEC.md`, and `sos_arm_button.dart` in particular is a best-in-class reference: physics-aware press/countdown animation, haptics, `reduceMotion` handling, `RepaintBoundary`). This todo is about bringing the rest of the app up to that same tactile/motion quality bar, not a rebuild.

Grounded findings (file/line references as of 2026-08-11, `mobile/lib`, 104 Dart files):

1. **No custom page transitions anywhere.** `app_router.dart` has 27 `GoRoute` entries; every one uses a plain `builder:` (default platform `MaterialPage` transition). Zero `CustomTransitionPage`/`pageBuilder` usage in the whole app. Only one `Hero` exists (the splash/welcome logo). This is the single biggest lever for a "smoother" feel per the user's ask — add intentional transitions (fade for auth/tab-like swaps, slide for drill-down), per the `flutter-ui` skill's curve reference (`Curves.easeInOut`, 250-300ms standard).

2. **Uneven animation coverage** — only 12 of 104 lib files use any animation widget at all. Well-animated: `sos_arm_button.dart`, `main_shell.dart` (nav item `AnimatedContainer`/`AnimatedScale`), `welcome_screen.dart` (entrance fade+slide), `splash_screen.dart`, `animated_safepath_mark.dart`. Zero entrance/transition animation: `history_timeline_screen`, `profile_screen`, `privacy_center_screen`, `privacy_policy_screen`, `emergency_contacts_screen`, `member_detail_sheet`, `route_stats_sheet`, `battery_transparency_screen`, family screens (`create_circle`, `invite_member`, `manage_permissions`, `accept_invite`), `responder_alert_screen`, `sender_emergency_session_screen` (partial).

3. **Buttons lack tactile feedback.** `shared_widgets/primary_button.dart` and `secondary_button.dart` are thin static wrappers around `ElevatedButton`/`OutlinedButton` — no press-scale, no haptic — while `sos_arm_button.dart` has a deliberate press-in micro-interaction. The app-wide CTAs should get a shared subtle press-scale (~0.97, ~100-140ms) + `HapticFeedback.selectionClick()` to match the tactile bar the SOS button already sets.

4. **Icons are 100% stock Material Icons** throughout (`Icons.map_outlined`, etc.) — consistent but generic. Low priority; verify `01-UI-SPEC.md` doesn't already lock this before touching.

5. **13 static `ListView(children: [...])` instances** flagged by `scripts/flutter_ui_audit.py` (part of the `flutter-ui` skill) instead of `.builder()`: `profile_screen`, `privacy_center_screen`, `privacy_policy_screen`, `battery_transparency_screen`, `history_timeline_screen`, `permission_priming_screen`, `route_stats_sheet`, `landing_stub_screen` (x3), `invite_member_screen`, `manage_permissions_screen`, `emergency_contacts_screen`. Most lists are short/bounded so real-world impact is low, but it's the project's own stated anti-pattern (see `flutter-ui` skill) — worth a consistency pass.

6. **2 Riverpod providers defined inside a class** instead of top-level — `sos_controller.dart:48`, `deep_link_service.dart:45` — creates a new provider instance per build. Not visual, but can cause avoidable rebuild churn/jank; worth fixing alongside the animation pass since it affects perceived smoothness.

7. **Two "zero-duration animation" audit flags** — `member_detail_sheet.dart:133` and `welcome_screen.dart:36` — likely both intentional `reduceMotion ? Duration.zero : ...` accessibility patterns (matches the pattern already confirmed correct in `welcome_screen.dart` and `sos_arm_button.dart`), but worth a quick confirm that `member_detail_sheet.dart:133` is the same deliberate pattern and not a leftover mistake.

8. **Modal/bottom sheets** (`member_detail_sheet.dart`, `route_stats_sheet.dart`) — verify they use a custom rounded-sheet entrance consistent with the app's flat-card design language rather than the default Material bottom-sheet slide, as part of the same pass.

## Solution

Not scoped yet — TBD. Suggested approach when picked up: run this as its own phase (or fold into a future UI-focused phase) via `/gsd-plan-phase`, loading the `/flutter-ui` skill's reference files (`flutter-animations.md`, `flutter-theme-system.md`, `flutter-performance.md`) before touching code, and re-running `python mobile/lib -> scripts/flutter_ui_audit.py` (needs `PYTHONIOENCODING=utf-8` on Windows) before/after to confirm no regressions. Start with item 1 (page transitions) since it's app-wide and highest perceived-smoothness payoff per line of code changed; items 3 (button tactility) and 2 (animation coverage) next; items 4-8 are smaller/lower-priority cleanup that can ride along.
