import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../family/application/family_controller.dart';
import '../data/location_api.dart';
import '../data/location_models.dart';

class HistoryState {
  const HistoryState({
    this.selectedTargetUserId,
    this.fromUtc,
    this.toUtc,
    this.history = const LocationHistory(),
    this.stats = const TravelStats(),
    this.error,
    this.isLoading = false,
  });

  final String? selectedTargetUserId;
  final DateTime? fromUtc;
  final DateTime? toUtc;
  final LocationHistory history;
  final TravelStats stats;
  final String? error;
  final bool isLoading;

  bool get isEmpty => error == null && !isLoading && history.isEmpty;
  String get emptyTitle => 'No history yet';

  HistoryState copyWith({
    String? selectedTargetUserId,
    DateTime? fromUtc,
    DateTime? toUtc,
    LocationHistory? history,
    TravelStats? stats,
    String? error,
    bool clearError = false,
    bool? isLoading,
  }) {
    return HistoryState(
      selectedTargetUserId: selectedTargetUserId ?? this.selectedTargetUserId,
      fromUtc: fromUtc ?? this.fromUtc,
      toUtc: toUtc ?? this.toUtc,
      history: history ?? this.history,
      stats: stats ?? this.stats,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HistoryController extends AsyncNotifier<HistoryState> {
  @override
  HistoryState build() => const HistoryState();

  HistoryState get _current => state.value ?? const HistoryState();

  Future<void> load(
    String targetUserId,
    DateTime fromUtc,
    DateTime toUtc,
  ) async {
    final familyId = ref.read(familyControllerProvider).value?.family?.id;
    if (familyId == null) {
      state = AsyncData(
        _current.copyWith(
          selectedTargetUserId: targetUserId,
          fromUtc: fromUtc.toUtc(),
          toUtc: toUtc.toUtc(),
          isLoading: false,
          error: 'No family circle found.',
        ),
      );
      return;
    }

    final api = ref.read(locationApiProvider);
    final normalizedFrom = fromUtc.toUtc();
    final normalizedTo = toUtc.toUtc();
    state = AsyncData(
      _current.copyWith(
        selectedTargetUserId: targetUserId,
        fromUtc: normalizedFrom,
        toUtc: normalizedTo,
        isLoading: true,
        clearError: true,
      ),
    );

    try {
      final results = await Future.wait<Object>([
        api.getHistory(familyId, targetUserId, normalizedFrom, normalizedTo),
        api.getTravelStats(
          familyId,
          targetUserId,
          normalizedFrom,
          normalizedTo,
        ),
      ]);
      state = AsyncData(
        _current.copyWith(
          history: results[0] as LocationHistory,
          stats: results[1] as TravelStats,
          isLoading: false,
          clearError: true,
        ),
      );
    } on LocationApiException catch (error) {
      state = AsyncData(
        _current.copyWith(
          history: const LocationHistory(),
          stats: const TravelStats(),
          isLoading: false,
          error: error.message,
        ),
      );
    }
  }
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, HistoryState>(
      HistoryController.new,
    );
