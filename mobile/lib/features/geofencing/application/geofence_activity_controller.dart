import '../data/geofence_api.dart';

class GeofenceActivityState {
  const GeofenceActivityState({
    this.filters = const GeofenceActivityFilters(),
    this.activity = const [],
    this.isLoading = false,
    this.error,
  });

  final GeofenceActivityFilters filters;
  final List<GeofenceActivity> activity;
  final bool isLoading;
  final String? error;

  GeofenceActivityState copyWith({
    GeofenceActivityFilters? filters,
    List<GeofenceActivity>? activity,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => GeofenceActivityState(
    filters: filters ?? this.filters,
    activity: activity ?? this.activity,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Stateful request coordinator kept independent from widgets so retries and
/// filter changes cannot allow an older response to replace the current view.
class GeofenceActivityController {
  GeofenceActivityController(this._api, this._clock);

  final GeofenceApi _api;
  final DateTime Function() _clock;
  GeofenceActivityState state = const GeofenceActivityState();
  int _requestSequence = 0;

  Future<void> load(
    GeofenceActivityFilters filters, {
    required String familyId,
  }) async {
    final request = ++_requestSequence;
    final clamped = filters.clampToRetention(_clock());
    state = state.copyWith(filters: clamped, isLoading: true, clearError: true);
    try {
      final activity = await _api.activity(familyId, clamped);
      if (request != _requestSequence) return;
      state = GeofenceActivityState(filters: clamped, activity: activity);
    } on GeofenceApiException catch (error) {
      if (request != _requestSequence) return;
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (_) {
      if (request != _requestSequence) return;
      state = state.copyWith(
        isLoading: false,
        error: "Couldn't load zone activity. Check your connection and try again.",
      );
    }
  }
}
