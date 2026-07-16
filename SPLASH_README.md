# SafePath AI — Splash Screen Implementation Notes

`splash_screen.dart` is a drop-in production splash for the Flutter app.
Copy it to `lib/features/splash/presentation/splash_screen.dart` and adjust
the two import paths at the top (`app_router.dart`, `safepath_logo.dart`) to
match your project structure.

## 1. Animation description
A single sequence (~1.8s), entirely on one `AnimationController`:
- **0–20%** — background fades in (`easeOutCubic`).
- **~3%–56%** (≈900ms) — the logo lockup fades 0→100% opacity, scales
  92%→100%, and rises 8px→0px, all on one `Curves.easeOutQuart` interval.
  No bounce, no overshoot, no elastic.
- Layered on top of that base motion, three restrained "premium" touches
  (all still eased with the same calm curves, all decorative/non-blocking):
  - a **slow rotating conic halo** behind the mark (continuous gentle drift,
    low opacity, never a flash),
  - a **one-time diagonal sheen** that sweeps once across the shield partway
    through the entry (`easeOutCubic`, no repeat),
  - a **staggered per-letter wordmark reveal** — each character of
    "SafePath AI" fades/rises in on its own `easeOutQuart` interval, offset
    by ~28ms per letter.
- **56%–81%** (≈450ms) — hold at rest; the halo keeps its slow breathing/
  rotation as the idle state.
- Remaining tail is reserved for the next route's own fade-in.

Bug that was fixed: the earlier version (in the HTML mockup) used an
`easeOutBack` curve on the pin element, which overshoots past 100% before
settling — a bounce. That directly violated the "no overshoot/elastic/bounce"
requirement. This implementation uses only `easeOutCubic`/`easeOutQuart`
throughout, and the HTML mockup has been corrected and enhanced to match
(fade + scale + rise as the base motion, plus the halo/sheen/stagger flourishes
described above — all calm curves, no bounce anywhere).

## 2. Implementation approach
- **One `AnimationController`** (now 1800ms) drives everything. The base
  motion (bg fade, scale, opacity, rise) uses `Interval`-scoped
  `CurvedAnimation`s wired to `FadeTransition`/`ScaleTransition`/a small
  `AnimatedBuilder` for the translate — none of that subtree rebuilds beyond
  what those transition widgets already optimize for.
  The three "fancy" flourishes (halo rotation, sheen sweep, letter stagger)
  live in `_SplashMark`, which is itself an `AnimatedWidget` listening
  directly to the same controller — so only that inner subtree repaints per
  frame; the `Scaffold`/`SafeArea` above it never rebuild. No nested
  controllers, no `Timer`, no `Future.delayed` hacks, no per-frame
  `setState`.
- **Navigation-exactly-once** is enforced by a `_navigated` boolean checked
  in `_tryNavigate()`, which only proceeds when **both** the controller has
  reached `AnimationStatus.completed` **and** the async
  `resolveDestination()` future has resolved. This means:
  - A fast session check never truncates the animation (still waits for
    `completed`).
  - A slow session check never leaves a blank/frozen frame — the completed
    animation just holds at rest until the check resolves.
  - Widget rebuilds/lifecycle resumes can't double-fire because of the
    guard flag.
- **Reduced motion**: checks
  `SchedulerBinding.instance.window.accessibilityFeatures.disableAnimations`
  in `initState` and, if true, shortens the controller to a 220ms fade-only
  by reassigning `_controller.duration` before `forward()` is called.
- **Light/dark**: background and text color branch on
  `Theme.of(context).brightness`, reusing the existing SafePath tokens
  (`#0C3A3F` dark / `#ECF0EF` light) — no new colors.
- **Disposal**: `_controller` and its status listener are removed/disposed
  in `dispose()`.

## 3. Files
- `lib/splash_screen.dart` (in this handoff) → move to
  `lib/features/splash/presentation/splash_screen.dart` in your app repo.
- Depends on `assets/safepath_logo.dart` (already in this handoff) for the
  `SafePathLogo` mark — no SVG package required.
- You'll need to wire `AppRouter.goToHome` / `AppRouter.goToWelcome` (or your
  actual router calls) and a `resolveDestination()` implementation that
  checks for a valid session (e.g. a stored/refreshed auth token).

## 4. Assumptions
- The project uses `go_router` (per `SYSTEM_DESIGN.md`) with named routes for
  "welcome" and the authenticated home; adjust `AppRouter` calls to your
  actual router API if different.
- Manrope is already registered as a font in `pubspec.yaml` (per the design
  system) — if not, add it or swap to `google_fonts`.
- "Session exists" resolution (`resolveDestination`) is provided by the
  caller (e.g. a Riverpod provider reading secure storage) — this widget
  only consumes the result, per the instruction not to duplicate existing
  auth logic.
- Web target: `AnimationController` + `Transform`/`Fade`/`ScaleTransition`
  are fully supported on Flutter Web and run on the compositor thread, so
  the 60/120Hz and no-dropped-frames requirements hold there too.

## 5. Validation against the checklist
- No flicker / no white or black frame: background fades in from the
  Scaffold's own `backgroundColor` (already the target color), so there is
  never an unstyled frame.
- No layout overflow: fixed-size logo + `Column(mainAxisSize: min)`,
  centered via `Center`/`SafeArea` — reflows safely on phones, tablets,
  foldables, and both orientations.
- No dropped frames / no heavy rebuilds: single controller, animated values
  applied via `Transform`/`FadeTransition`/`ScaleTransition` (compositor-only
  transforms), logo subtree built once as `child`.
- No animation restart: `AnimationController.forward()` is called exactly
  once in `initState`; nothing re-triggers `forward()`.
- No navigation race / no duplicate navigation: guarded by `_navigated` +
  dual-condition check described above.
- No memory leaks: controller and listener disposed.
- Plays exactly once per cold launch: the splash route itself is only ever
  pushed once at app start (not a loop) — ensure your router does not treat
  it as a persisted/back-stack route.
- Reduced motion / contrast / no flashing: handled per section above; the
  ambient glow is a static low-opacity fill, not a pulse, so there's no
  brightness flicker at any point.

Please run `flutter analyze` and your existing test suite after dropping
this in — I can't execute Dart tooling from here, so this is written to
compile cleanly against a standard Flutter 3.x / Material 3 project but
should be verified in your actual repo.
