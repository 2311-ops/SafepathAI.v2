---
created: 2026-08-06T04:45:00.000Z
title: Family/self map pin visibly "rolls"/vibrates while panning the Live Map left-right
area: investigation
files:
  - mobile/lib/features/location/presentation/vector_map.dart (_onControllerNotified L270-276, _reprojectMarkers L341-, _onCameraIdle L285-290)
---

## Problem

Reported by the user after the 260806-3zb quick task (flutter_map -> maplibre_gl migration) shipped and was rebuilt on-device: panning the Live Map left/right makes the family/self avatar pin visibly "roll" or vibrate, rather than tracking the basemap smoothly. Not yet independently reproduced/investigated by me -- flagged for later per explicit user instruction, not fixed now.

## Impact

UX-only (no data/safety correctness issue -- the pin's *final*, settled position was already confirmed correct in 260806-3zb's on-device verification). But a visibly jittery pin during the single most common interaction on the app's primary screen (panning to look around the family map) is a real, user-facing quality regression versus the old flutter_map raster implementation, which moved the marker as a normal Flutter widget with no async round-trip.

## Suspected Area

`VectorMap`'s marker reprojection is fundamentally async per-frame: `MapLibreMapController` is a `ChangeNotifier` that fires `_onControllerNotified` on every native camera-move tick while a pan gesture is in progress (`vector_map.dart:270-276`), and each call fires an unguarded `_reprojectMarkers()` (`:341-`) which does a method-channel round-trip (`toScreenLocationBatch`) before calling `setState`. During a fast pan, many of these can be in flight concurrently with no in-flight/generation guard -- if two overlapping calls resolve **out of order** (a plausible race given they're separate awaited platform-channel calls), the marker's `_screenPositions` entry can briefly jump backward to an older, stale coordinate before the latest one lands, which would look exactly like a "roll"/vibrate rather than a smooth one-directional lag.

This is a related-but-distinct issue from two things already known/documented:
- RESEARCH.md's Pitfall 4 (accepted, expected): reprojection lagging the basemap by ~1 frame during motion, settling correctly on `onCameraIdle`. A single consistent frame of lag reads as "trailing," not "vibrating" -- if what's being seen is genuinely a back-and-forth jitter rather than a one-directional lag, that points at the race above, not Pitfall 4.
- The code review's WR-02 finding (advisory, not yet fixed): flagged the exact same "no in-flight guard on overlapping async calls" pattern for `_drawAnnotations()`, but explicitly did not check whether `_reprojectMarkers()` has the same structural gap. It does look structurally identical (no generation counter/token, no cancellation of a superseded call).

## First steps (not yet done)

1. Confirm the visual symptom directly on-device (screen-record a slow, deliberate left-right pan) before changing code, to distinguish "one consistent frame of lag" (expected, Pitfall 4) from "position jumping backward/forward mid-pan" (the race hypothesis above).
2. If it's the race: add a generation counter to `_reprojectMarkers()` (same pattern suggested for WR-02) so a newer call's result always wins and a superseded in-flight call's `setState` is dropped rather than applied.
3. Also worth checking whether `_onControllerNotified` is firing far more often than necessary (once per raw native frame vs. throttled), since reducing call frequency would reduce both the visual symptom and the method-channel overhead regardless of root cause.
