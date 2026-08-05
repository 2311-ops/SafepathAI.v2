---
created: 2026-08-05T21:20:00.000Z
title: Investigate FamilyController cold-start bootstrap issue (app relaunch shows "No circle yet" for a real family member)
area: investigation
files:
  - mobile/lib/features/family/application/family_controller.dart (build/_bootstrap, lines 65-119)
---

## Problem

Found incidentally during quick task 260805-uke's device verification (not caused by that task -- this file was not touched by it). On an Android emulator signed in as "mohh" (a confirmed active Guardian of family "bom"), an app-level relaunch (`am force-stop` + `monkey` launcher intent, i.e. the app process restarting but the OS/emulator staying up) left the app showing "No circle yet" on both the Live Map and Privacy Center, even though direct `GET /families/mine` calls against the backend with that account's own token correctly returned the family membership.

A **full emulator reboot** (`adb emu kill` + relaunch) resolved it cleanly on the next app launch -- the same account then loaded its family correctly.

## Impact

Low severity observed here (the app degrades safely -- screens that depend on family data show their empty/no-circle state rather than crashing or showing wrong data, and downstream consumers like the new `sosReachProvider` correctly stayed in their `unknown` state rather than showing anything false). But if this can happen to a real user on an app-level relaunch (not just in this adb-driven test environment), it would incorrectly tell them they have no family circle when they do, which is confusing and potentially alarming.

## Suspected Area

`FamilyController.build()` in `mobile/lib/features/family/application/family_controller.dart` (lines 65-119): registers `ref.listen<AuthState>(authControllerProvider, ...)` to call `_bootstrap()` on the `Unauthenticated -> Authenticated` transition, and separately calls `_bootstrap()` via `Future.microtask` if already authenticated at `build()` time. Worth checking whether there's a timing window on some relaunch paths where neither branch fires -- e.g. if the auth state is already `AuthAuthenticated` by the time this provider's `build()` runs, but through a path that doesn't match the exact object identity/timing this logic expects, or if a stale cached provider state from a previous app process persists in a way that skips bootstrap on the next cold build.

Not reproduced via a controlled unit test yet -- only observed once, on this device, during unrelated manual testing. First step should be trying to reproduce it deliberately (repeated force-stop + relaunch cycles) before making code changes.
