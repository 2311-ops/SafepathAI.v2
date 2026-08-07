---
type: quick
slug: 260807-qhg-apply-splash-screen-enhancement-instruct
title: Consolidate the splash lockup into a shared AnimatedSafePathMark with ring trace and staggered letter reveal
autonomous: true
files_modified:
  - mobile/lib/shared_widgets/animated_safepath_mark.dart
  - mobile/lib/features/splash/presentation/splash_screen.dart
  - mobile/test/features/splash/splash_screen_test.dart
requirements: [QUICK-SPLASH-SHARED-MARK, QUICK-SPLASH-RING-TRACE, QUICK-SPLASH-LETTER-STAGGER, QUICK-SPLASH-REDUCED-MOTION, QUICK-SPLASH-DURATION-SYNC]
must_haves:
  truths:
    - On cold launch the logo mark is encircled by a thin mint ring that traces from empty to a fully closed loop, computed from 2*pi*r so it can never leave a gap.
    - The words "SafePath AI" reveal one letter at a time, left to right, each fading up and rising 6px on its own easeOutQuart interval instead of appearing as one static block.
    - The halo behind the mark visibly rotates (0.42 turns) across the launch window rather than the barely-perceptible 43 degrees it drifted before.
    - Both the routed /splash page and the cold-start overlay render the identical lockup, because both now build the same shared widget - there is no second copy of the glow/sheen/ring code left in the splash feature.
    - Both surfaces run for the same 1800ms so the overlay's fade-out at progress 0.86 still covers the handoff to the real route with no visible seam or flash.
    - With MediaQuery.disableAnimations set, both surfaces render the resting frame instantly - no ring, no sheen, no per-letter stagger, no halo rotation - and the wordmark is a single centred Text again.
    - A screen reader announces the wordmark once as "SafePath AI", not as eleven separate letters.
    - The wordmark never overflows its row on a narrow screen or at a large system text scale.
  artifacts:
    - mobile/lib/shared_widgets/animated_safepath_mark.dart (AnimatedSafePathMark public widget + private _Mark, _RingPainter, _SheenSweep, _StaggeredWordmark)
    - mobile/lib/features/splash/presentation/splash_screen.dart (both lockups rewired onto the shared widget, duplicate mark/sheen code removed, durations synced to 1800ms)
    - mobile/test/features/splash/splash_screen_test.dart (wordmark asserted via concatenated letter Texts, timings corrected to 1800ms, reduced-motion ring absence covered for both surfaces)
  key_links:
    - AnimatedSafePathMark extends AnimatedWidget and listens to whatever Animation<double> it is handed - SplashScreen hands it the raw AnimationController, StartupSplashOverlay hands it the AlwaysStoppedAnimation<double> already built at splash_screen.dart:252. If either stops being a live 0..1 source the mark silently freezes at its first frame with no error.
    - The reduceMotion flag is the single accessibility contract - it is read once per surface from MediaQuery.disableAnimations and must be threaded into AnimatedSafePathMark unchanged; if it is dropped the ring, sheen and stagger all reappear under disableAnimations.
    - _RingPainter derives its sweep from 2 * math.pi * progress against the same radius it strokes, so the closed-loop guarantee is structural rather than a hardcoded circumference constant.
    - AnimatedSafePathMark.ringKey is the only test-visible handle proving the ring is drawn (or correctly absent under reduced motion); the painter itself is private.
    - splash_screen_test.dart's 1850ms pump sits just past SplashScreen._defaultDuration - the two are coupled, and raising the duration without raising the pump silently turns the completion-gate test into a false failure.
---

<objective>
Apply `design_handoff_safepath_ai/lib/SPLASH_ENHANCEMENT_INSTRUCTIONS.md` to the real splash feature: introduce one shared `AnimatedSafePathMark` widget that adds the missing progress ring and per-letter wordmark reveal from the "00 - App Open" hi-fi mockup, and collapse the two near-duplicate lockup implementations in `splash_screen.dart` onto it.

Purpose: Today `SplashScreen` and `StartupSplashOverlay` each carry their own copy of the glow/sheen code, neither has a ring or a staggered wordmark, the halo drift is imperceptible, and the two clocks run at different durations (1400ms vs 1600ms). Any future motion tweak has to be made twice and can drift. One shared widget makes that class of bug structurally impossible.

Output: A new `mobile/lib/shared_widgets/animated_safepath_mark.dart`, a slimmed `splash_screen.dart` whose two surfaces both consume it, and updated splash tests that survive the wordmark becoming per-letter widgets.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@design_handoff_safepath_ai/lib/SPLASH_ENHANCEMENT_INSTRUCTIONS.md
@design_handoff_safepath_ai/lib/animated_safepath_mark.dart
@mobile/lib/features/splash/presentation/splash_screen.dart
@mobile/lib/shared_widgets/safepath_logo.dart
@mobile/test/features/splash/splash_screen_test.dart
</context>

<interface_context>
Signatures the executor needs and must not re-derive:

- `SafePathLogo({Key? key, double size = 64, bool tile = true})` - pure `CustomPaint`, no theme dependency. `tile: false` draws the bare mark on a transparent background. Call site is exactly `const SafePathLogo(size: 96, tile: false)`.
- `AppColors.accentMint` = `Color(0xFF79D6C9)` in `mobile/lib/core/theme/app_colors.dart`. No new colors are introduced by this task.
- `AppTypography.display` is a **static getter** (`static TextStyle get display => GoogleFonts.manrope(fontSize: 38, fontWeight: FontWeight.w800, height: 1.05, letterSpacing: 0, color: AppColors.ink)`), not a const field - so `AppTypography.display.copyWith(color: Colors.white)` can never appear inside a `const` expression.
- `AppSpacing.md` = 16, `AppSpacing.lg` = 24 (4pt scale from `01-UI-SPEC.md`).
- Import path from `mobile/lib/shared_widgets/` to the theme layer is `../core/theme/<file>.dart` - the handoff file's existing `import '../core/theme/app_colors.dart';` is already correct for the destination and needs no edit.
- `splash_screen.dart:252` already wraps the overlay's `Timer`-driven double as `AlwaysStoppedAnimation<double>(_progress)` before handing it to `_StartupSplashSurface.progress`, which is typed `Animation<double>`. No new wrapping is needed inside the surface - the value flows straight through.
- `mobile/lib/app.dart:65` calls `StartupSplashOverlay(child: routedChild)`. That public constructor is unchanged by this task, so `app.dart` must not be touched.
</interface_context>

<tasks>

<!-- planner-discipline-allow: _AnimatedLogoMark -->
<!-- planner-discipline-allow: _SheenSweep -->

<task type="auto" tdd="false">
  <name>Task 1: Add the shared AnimatedSafePathMark widget</name>
  <files>mobile/lib/shared_widgets/animated_safepath_mark.dart</files>
  <behavior>
    - At progress 0 with reduceMotion false: the ring's traced arc has zero sweep, the wordmark letters are all at zero opacity, the mark is at 92 percent scale via the caller's transform.
    - At progress 1: the ring arc sweeps a full 2*pi (closed loop), every letter is at full opacity and zero rise.
    - With reduceMotion true at any progress: no ring widget is built at all, no sheen widget is built, the wordmark is a single centred Text, and the halo rotation angle is zero.
  </behavior>
  <action>
Create `mobile/lib/shared_widgets/animated_safepath_mark.dart` by porting `design_handoff_safepath_ai/lib/animated_safepath_mark.dart` verbatim, including its header comment block documenting the motion budget, then applying exactly these six integration edits and nothing else:

1. Keep the existing `import '../core/theme/app_colors.dart';` unchanged - it already resolves correctly from `shared_widgets/`. Add two sibling/relative imports: `import 'safepath_logo.dart';` and `import '../core/theme/app_spacing.dart';`.

2. Delete the two placeholder classes at the bottom of the handoff file - the one that only forwards to a reference stub, and the reference stub itself that throws `UnimplementedError`. In `_Mark`'s `Stack` children, replace the `const ExcludeSemantics(child: ...)` entry that pointed at the deleted stub with `const ExcludeSemantics(child: SafePathLogo(size: 96, tile: false))`. There must be no indirection layer left between `_Mark` and `SafePathLogo`.

3. Replace the hardcoded `const SizedBox(height: 18)` between the mark and the wordmark with `const SizedBox(height: AppSpacing.lg)`. Rationale to record in the SUMMARY: 18 is not a value on the project's fixed 4pt spacing scale, `AppSpacing.lg` (24) is what the current splash already ships and what `01-UI-SPEC.md` specifies, and per the project constraints the spacing scale is fixed and not open to redesign by a handoff file that was written without knowledge of the token set.

4. Expose a test handle for the ring, since the painter is private and there is otherwise no automated way to prove the accessibility contract holds. On `AnimatedSafePathMark`, add `@visibleForTesting static const ValueKey<String> ringKey = ValueKey<String>('animated-safepath-mark-ring');` and pass `key: AnimatedSafePathMark.ringKey` to the `CustomPaint` inside `_Mark` that hosts the ring painter. Import `package:flutter/foundation.dart` if `visibleForTesting` is not already in scope via `material.dart`.

5. Fix the screen-reader regression the per-letter split introduces. In `_StaggeredWordmark`, the non-reduced-motion branch currently returns a bare `Row` of eleven single-character `Text` widgets, which assistive tech would announce letter by letter. Wrap that `Row` as `Semantics(label: text, container: true, child: ExcludeSemantics(child: <Row>))` so the whole lockup announces once with the full word. Leave the reduced-motion branch as the plain centred `Text` it already is - it needs no wrapper.

6. Guard the same `Row` against layout overflow. Unlike the single `Text` it replaces, a `Row` cannot soft-wrap, so at a large system text scale or on a narrow device the 38px display style would trip a `RenderFlex` overflow. Insert `FittedBox(fit: BoxFit.scaleDown, child: <Row>)` between the `ExcludeSemantics` from edit 5 and the `Row`. At normal text scale this is a visual no-op.

Do not alter any of the ported motion constants (`_wordStart` 0.30, `_letterStagger` 0.028, `_letterDuration` 0.34, the sheen window 0.34-0.72, the 0.42-turn halo drift, the entry/ring intervals 0.55/0.60), the curves, the ring radius of 66.0, or the 2.2 stroke width. Introduce no colors beyond `AppColors.accentMint` and the `Colors.white` alphas the handoff already uses.
  </action>
  <verify>
    <automated>cd mobile &amp;&amp; flutter analyze --no-pub lib/shared_widgets/animated_safepath_mark.dart</automated>
    <automated>cd mobile &amp;&amp; grep -q "SafePathLogo(size: 96, tile: false)" lib/shared_widgets/animated_safepath_mark.dart</automated>
    <automated>cd mobile &amp;&amp; grep -c "UnimplementedError" lib/shared_widgets/animated_safepath_mark.dart | grep -qx 0</automated>
    <automated>cd mobile &amp;&amp; grep -q "2 \* math.pi \* progress" lib/shared_widgets/animated_safepath_mark.dart</automated>
  </verify>
  <done>`animated_safepath_mark.dart` exists in `mobile/lib/shared_widgets/`, analyzes clean with no unused imports and no unresolved references, renders `SafePathLogo` directly with no placeholder indirection, derives the ring sweep from `2 * math.pi * progress` rather than a constant, exposes `ringKey`, and wraps the staggered letter row in both a merged `Semantics` label and a scale-down `FittedBox`.</done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Rewire both splash surfaces onto the shared widget and sync durations to 1800ms</name>
  <files>mobile/lib/features/splash/presentation/splash_screen.dart</files>
  <behavior>
    - `SplashScreen` builds exactly one `AnimatedSafePathMark` fed by its `AnimationController`, and flips `splashAnimationCompleteProvider` once at 1800ms (220ms under reduced motion).
    - `_StartupSplashSurface` builds exactly one `AnimatedSafePathMark` fed by the `Animation<double>` it already receives, and the overlay clears itself at 1800ms (260ms under reduced motion).
    - No sibling static wordmark `Text` survives in either lockup - the wordmark is owned entirely by the shared widget.
  </behavior>
  <action>
Edit `mobile/lib/features/splash/presentation/splash_screen.dart` only. Do not touch `mobile/lib/app.dart` - `StartupSplashOverlay`'s public constructor is unchanged, so its call site at `app.dart:65` stays valid.

1. Add `import '../../../shared_widgets/animated_safepath_mark.dart';` alongside the existing relative imports.

2. Rewrite `_SplashScreenState._buildLockup()` to return the shared widget directly instead of building its own `Column`. It becomes a single expression returning `AnimatedSafePathMark(progress: _controller, reduceMotion: _reduceMotion, wordmarkStyle: AppTypography.display.copyWith(color: Colors.white))`. The `Column`, the spacer `SizedBox`, and the static wordmark `Text` that currently sit inside it all go away - the shared widget supplies all three. Note this expression cannot be `const` because `AppTypography.display` is a getter.

3. In `_StartupSplashSurface.build`, replace the `Column` passed as the `AnimatedBuilder`'s `child:` argument with the same `AnimatedSafePathMark(progress: progress, reduceMotion: reduceMotion, wordmarkStyle: AppTypography.display.copyWith(color: Colors.white))`. Pass the `progress` field through untouched - it is already an `Animation<double>` because the caller wraps the raw double at line 252. Leave the surrounding `Material` / gradient `Container` / `SafeArea` / `Center` / `RepaintBoundary` / `FadeTransition` / `ScaleTransition` / `AnimatedBuilder` chain exactly as it is.

4. Delete the two now-orphaned private classes at the bottom of the file: the animated logo mark class and the sheen sweep class. Both call sites consume the shared widget's built-in sheen now.

5. Change `_SplashScreenState._defaultDuration` from `Duration(milliseconds: 1400)` to `Duration(milliseconds: 1800)`, and `_StartupSplashOverlayState._defaultDuration` from `Duration(milliseconds: 1600)` to `Duration(milliseconds: 1800)`. Leave both reduced-motion durations (220ms and 260ms) and `_postFrameStartDelay` untouched. The two surfaces must now agree so the overlay's fade-out window at progress 0.86 still lands over the route handoff.

6. Update the `SplashScreen` class doc comment: it currently describes a "1400ms `AnimationController`" - correct that figure to 1800ms and extend the motion description to mention the traced ring and the staggered wordmark so the doc no longer contradicts the code.

7. Prune imports that the deletions made unused, since the analyzer treats unused imports as warnings. After step 4 the file no longer references `dart:math` (only the deleted halo rotation used it) or `SafePathLogo` (only the deleted mark used it), and after steps 2 and 3 it no longer references `AppSpacing` (both usages were the spacer that moved into the shared widget). Remove those three imports. Keep `dart:async` (the overlay's `Timer`), `AppColors` (both gradients), and `AppTypography` (the wordmark style).

Do not convert `StartupSplashOverlay` to an `AnimationController` - the handoff lists that as optional and explicitly not required for this fix, and it is out of scope here.
  </action>
  <verify>
    <automated>cd mobile &amp;&amp; flutter analyze --no-pub</automated>
    <automated>cd mobile &amp;&amp; grep -c "AnimatedSafePathMark(" lib/features/splash/presentation/splash_screen.dart | grep -qx 2</automated>
    <automated>cd mobile &amp;&amp; grep -v '^\s*//' lib/features/splash/presentation/splash_screen.dart | grep -c "_AnimatedLogoMark" | grep -qx 0</automated>
    <automated>cd mobile &amp;&amp; grep -v '^\s*//' lib/features/splash/presentation/splash_screen.dart | grep -c "_SheenSweep" | grep -qx 0</automated>
    <automated>cd mobile &amp;&amp; grep -c "milliseconds: 1800" lib/features/splash/presentation/splash_screen.dart | grep -qx 2</automated>
    <automated>cd mobile &amp;&amp; grep -v '^\s*//' lib/features/splash/presentation/splash_screen.dart | grep -c "'SafePath AI'" | grep -qx 0</automated>
    <automated>cd mobile &amp;&amp; git diff --quiet -- lib/app.dart</automated>
  </verify>
  <done>`flutter analyze` is clean across the whole package. `splash_screen.dart` contains exactly two `AnimatedSafePathMark` call sites, zero references to the two deleted private classes, zero literal wordmark strings, and two `1800` millisecond durations. `lib/app.dart` is untouched.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Update splash tests for the per-letter wordmark and the 1800ms window</name>
  <files>mobile/test/features/splash/splash_screen_test.dart</files>
  <behavior>
    - Test 1 (content renders): with motion enabled, `SafePathLogo` is present once and the concatenated wordmark letters spell "SafePath AI".
    - Test 2 (gate flips once): the completion gate is still false at first pump, true after pumping just past 1800ms, and flips exactly once thereafter.
    - Test 3 (reduced motion, SplashScreen): after 250ms the wordmark reads "SafePath AI", the gate is true, and the ring is absent.
    - Test 4 (ring, motion enabled): mid-animation the ring is present.
    - Test 5 (reduced motion, StartupSplashOverlay): the overlay renders the wordmark with no ring, then clears to reveal its child.
    - Test 6 (disposal): unchanged, still leaves no exception.
  </behavior>
  <action>
Edit `mobile/test/features/splash/splash_screen_test.dart` only. Investigation confirmed this is the sole test file affected: the `find.text('SafePath AI')` assertions in `test/widget_test.dart:78`, `test/theme_test.dart:117`, `test/core/router/pending_invite_redirect_test.dart:53` and `test/core/router/auth_flow_navigation_test.dart:321,340` all run after `pumpAndSettle()` has moved the app off `/splash`, so they are asserting on the Welcome screen's own wordmark (`welcome_screen.dart:69`) and are unaffected. `test/features/splash/splash_redirect_gate_test.dart:74` pumps only 700ms before asserting the gate still holds, which stays true at 1800ms. Confirm both facts by running those suites in the verify step rather than editing them.

1. Add `import 'package:mobile/shared_widgets/animated_safepath_mark.dart';` to the test imports.

2. Add a top-level helper above `main()` that reads the wordmark in a way that works in both motion modes. It should collect every `Text` widget descending from the single `AnimatedSafePathMark`, join their `data` in order, and normalise the non-breaking space the staggered renderer substitutes for the literal space back into a regular space, returning the resulting `String`. Under reduced motion this yields the one plain `Text`; under full motion it yields the eleven letters joined. Use `tester.widgetList<Text>(find.descendant(of: find.byType(AnimatedSafePathMark), matching: find.byType(Text)))` as the collection source.

3. In the "content renders" test, keep the `SafePathLogo` assertion as is and replace the single-`Text` wordmark assertion with an equality check against the helper's return value. The old assertion cannot survive - with motion enabled the wordmark is now eleven separate one-character `Text` widgets, so a whole-string text finder matches nothing.

4. In the "animation runs once and flips the gate exactly once" test, raise the pump from 1450ms to 1850ms and update the explanatory comment above it, which currently cites the controller's duration as 1400ms, to cite 1800ms. Keep the existing reasoning about pumping past the boundary rather than landing exactly on it, and keep the trailing 1000ms pump that proves there is no double-flip.

5. In the reduced-motion test, replace the wordmark assertion with the helper equality check, keep the gate assertion, and add `expect(find.byKey(AnimatedSafePathMark.ringKey), findsNothing)` to lock in the accessibility contract that no ring is drawn under `disableAnimations`.

6. Add a new test that mounts `SplashScreen` with motion enabled, pumps roughly 900ms into the window, and asserts `find.byKey(AnimatedSafePathMark.ringKey)` finds one widget - the positive counterpart to the assertion in step 5.

7. Add a new test group for `StartupSplashOverlay` under `disableAnimations`, since the handoff's verification checklist calls for covering both surfaces and no test currently exercises the overlay at all. Mount `MediaQuery(data: MediaQueryData(disableAnimations: true), child: MaterialApp(home: StartupSplashOverlay(child: <a distinctively-keyed placeholder>)))`. After the initial pump plus enough time for the 120ms post-frame start delay to elapse but before the 260ms reduced-motion window closes, assert the helper reads the wordmark and that the ring key finds nothing. Then pump past the full window and assert the overlay has cleared - the placeholder child is findable and no `AnimatedSafePathMark` remains. The overlay drives itself off `Timer.periodic`, which the widget tester's fake-async clock advances normally, so no real delays are needed. Note the overlay is a plain `StatefulWidget` with no Riverpod dependency, so this group needs no `ProviderContainer`.

Leave the existing disposal test untouched.
  </action>
  <verify>
    <automated>cd mobile &amp;&amp; flutter analyze --no-pub test/features/splash/splash_screen_test.dart</automated>
    <automated>cd mobile &amp;&amp; flutter test test/features/splash/splash_screen_test.dart</automated>
    <automated>cd mobile &amp;&amp; flutter test test/features/splash/splash_redirect_gate_test.dart</automated>
    <automated>cd mobile &amp;&amp; flutter test test/widget_test.dart test/theme_test.dart</automated>
    <automated>cd mobile &amp;&amp; flutter test test/core/router</automated>
    <automated>cd mobile &amp;&amp; flutter test</automated>
  </verify>
  <done>The full `flutter test` suite passes green with zero edits to any test file other than `splash_screen_test.dart`. The splash suite proves the wordmark still spells "SafePath AI" in both motion modes, that the gate flips exactly once at the new 1800ms duration, that the ring is drawn with motion enabled and absent under `disableAnimations`, and that `StartupSplashOverlay` honours the same reduced-motion contract and still clears itself.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| (none introduced) | This change is entirely local UI rendering. No network call, no persistence, no user input, no new dependency, and no new permission crosses any boundary. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-QHG-01 | Denial of Service | `_StaggeredWordmark` per-frame rebuild on the cold-launch path | low | mitigate | Eleven `Text` widgets rebuilt per frame for 1800ms sits inside the existing `RepaintBoundary` both surfaces already wrap the lockup in, so raster work stays scoped to the lockup subtree. The SOS fast path is not mounted during splash, so no emergency latency budget is touched. |
| T-QHG-02 | Denial of Service | `FittedBox` overflow guard on the wordmark row | low | mitigate | Without it, a large system text scale would trip a `RenderFlex` overflow and paint a debug stripe over the launch screen. Task 1 edit 6 installs the guard. |
| T-QHG-03 | Information Disclosure | Screen-reader announcement of the wordmark | low | mitigate | Splitting the wordmark into per-letter nodes would leak an unusable letter-by-letter announcement to assistive tech. Task 1 edit 5 merges them behind one `Semantics(label: 'SafePath AI')` node. |
| T-QHG-04 | Tampering | Package installs | n/a | accept | No `pub add`, no dependency change, no `pubspec.yaml` edit. The package legitimacy gate does not apply to this task. |
</threat_model>

<verification>
1. `cd mobile && flutter analyze` reports no issues across the package.
2. `cd mobile && flutter test` passes the entire suite.
3. `git diff --stat` shows exactly three changed files: the new shared widget, `splash_screen.dart`, and `splash_screen_test.dart`. In particular `mobile/lib/app.dart` is unchanged.
4. Handoff checklist, confirmed by the automated gates above: ring closes fully (derived from `2*pi*r`, gated by grep in Task 1); letters reveal independently (proved by the eleven-`Text` concatenation helper in Task 3); halo drift raised to 0.42 turns (ported constant, untouched); `disableAnimations` renders at rest on both surfaces (Task 3 tests 3 and 5); overlay fade-out window still covers the route handoff (both durations now 1800ms, `splash_redirect_gate_test.dart` still green).
</verification>

<success_criteria>
- `mobile/lib/shared_widgets/animated_safepath_mark.dart` is the single source of truth for the launch lockup, consumed by both splash surfaces.
- `splash_screen.dart` contains no duplicate mark, sheen, glow, or wordmark code, and both durations read 1800ms.
- `flutter analyze` clean and `flutter test` fully green.
- `mobile/lib/app.dart` untouched.
- No new color, spacing, or motion value beyond what the handoff and the existing `AppColors`/`AppSpacing` tokens already define.
</success_criteria>

<output>
Create `.planning/quick/260807-qhg-apply-splash-screen-enhancement-instruct/260807-qhg-SUMMARY.md` when done.

Record in the SUMMARY: the `AppSpacing.lg` (24) versus handoff `18` spacing deviation and its rationale; the two additions beyond the handoff's literal instructions (the merged `Semantics` label and the `FittedBox` overflow guard, both remediating regressions the per-letter split itself introduces); and the finding that only `splash_screen_test.dart` needed updating because every other `'SafePath AI'` test assertion targets the Welcome screen after `pumpAndSettle()`, not the splash.
</output>
