import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../family/application/family_controller.dart';
import '../../location/application/history_controller.dart';
import '../../location/application/location_controller.dart';
import '../data/privacy_api.dart';
import '../data/privacy_models.dart';

const _saveSettingError =
    "Couldn't save that setting. Check your connection and try again.";
const _exportError = "Couldn't prepare your export. Try again in a moment.";

final privacyNowProvider = Provider<DateTime Function()>(
  (ref) => () => DateTime.now().toUtc(),
);

class PrivacyState {
  const PrivacyState({
    this.matrix = const SharingMatrix(),
    this.error,
    this.exportJson,
    this.isLoading = false,
    this.isExporting = false,
    this.isDeleting = false,
  });

  final SharingMatrix matrix;
  final String? error;
  final String? exportJson;
  final bool isLoading;
  final bool isExporting;
  final bool isDeleting;

  PrivacyState copyWith({
    SharingMatrix? matrix,
    String? error,
    String? exportJson,
    bool clearError = false,
    bool clearExport = false,
    bool? isLoading,
    bool? isExporting,
    bool? isDeleting,
  }) {
    return PrivacyState(
      matrix: matrix ?? this.matrix,
      error: clearError ? null : (error ?? this.error),
      exportJson: clearExport ? null : (exportJson ?? this.exportJson),
      isLoading: isLoading ?? this.isLoading,
      isExporting: isExporting ?? this.isExporting,
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }

  bool isEnabled(String? recipientId, SharedDataType dataType) =>
      matrix.isEnabled(recipientId, dataType);

  Duration? timeRemaining(
    String? recipientId,
    SharedDataType dataType, {
    required DateTime now,
  }) =>
      matrix.timeRemaining(recipientId, dataType, now: now);
}

class PrivacyController extends AsyncNotifier<PrivacyState> {
  String? _loadedFamilyId;

  @override
  PrivacyState build() {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthUnauthenticated) {
        _loadedFamilyId = null;
        state = const AsyncData(PrivacyState());
      } else if (next is AuthAuthenticated) {
        _loadForCurrentFamily();
      }
    });

    ref.listen<AsyncValue<FamilyState>>(familyControllerProvider, (
      previous,
      next,
    ) {
      final familyId = next.value?.family?.id;
      if (familyId != null && familyId != _loadedFamilyId) {
        _loadForCurrentFamily();
      }
    });

    if (ref.read(authControllerProvider) is AuthAuthenticated &&
        ref.read(familyControllerProvider).value?.family?.id != null) {
      Future.microtask(_loadForCurrentFamily);
      return const PrivacyState(isLoading: true);
    }

    return const PrivacyState();
  }

  PrivacyState get _current => state.value ?? const PrivacyState();

  Future<void> refresh() => _loadForCurrentFamily(force: true);

  Future<void> _loadForCurrentFamily({bool force = false}) async {
    final familyId = ref.read(familyControllerProvider).value?.family?.id;
    if (familyId == null) return;
    if (!force && _loadedFamilyId == familyId && !_current.isLoading) return;

    final api = ref.read(privacyApiProvider);
    state = AsyncData(_current.copyWith(isLoading: true, clearError: true));
    try {
      final matrix = await api.getSharingMatrix(familyId);
      _loadedFamilyId = familyId;
      state = AsyncData(
        _current.copyWith(matrix: matrix, isLoading: false, clearError: true),
      );
    } on PrivacyApiException catch (error) {
      state = AsyncData(
        _current.copyWith(isLoading: false, error: error.message),
      );
    } catch (_) {
      state = AsyncData(
        _current.copyWith(isLoading: false, error: 'Something went wrong. Try again.'),
      );
    }
  }

  Future<void> toggle({
    String? recipientId,
    required SharedDataType dataType,
    required bool enabled,
    DateTime? expiresAtUtc,
    DateTime? startedAtUtc,
  }) async {
    final familyId = ref.read(familyControllerProvider).value?.family?.id;
    if (familyId == null) return;

    final api = ref.read(privacyApiProvider);
    final before = _current;
    final previousCell = before.matrix.cellFor(recipientId, dataType);
    final optimisticCell = (previousCell ??
            SharingCell(
              recipientId: recipientId,
              dataType: dataType,
              isEnabled: !enabled,
            ))
        .copyWith(
      isEnabled: enabled,
      expiresAtUtc: expiresAtUtc,
      clearExpiry: expiresAtUtc == null,
      startedAtUtc: startedAtUtc,
      // A share with no expiry can't be temporary, so drop any stale start.
      clearStarted: expiresAtUtc == null,
    );

    state = AsyncData(
      before.copyWith(
        matrix: before.matrix.upsert(optimisticCell),
        clearError: true,
      ),
    );

    try {
      final updated = await api.updateSharingPreference(
        familyId,
        recipientMemberId: recipientId,
        dataType: dataType,
        isEnabled: enabled,
        expiresAtUtc: expiresAtUtc,
      );
      state = AsyncData(
        _current.copyWith(
          // The server round-trips expiresAtUtc but not startedAtUtc (a
          // client-only field), so re-attach the start we captured locally.
          matrix: _current.matrix.upsert(
            updated.copyWith(
              startedAtUtc: startedAtUtc,
              clearStarted: expiresAtUtc == null,
            ),
          ),
          clearError: true,
        ),
      );
    } on PrivacyApiException catch (error) {
      state = AsyncData(
        _current.copyWith(
          matrix: _revertedMatrix(recipientId, dataType, previousCell),
          error: error.message ?? _saveSettingError,
        ),
      );
    } catch (_) {
      state = AsyncData(
        _current.copyWith(
          matrix: _revertedMatrix(recipientId, dataType, previousCell),
          error: _saveSettingError,
        ),
      );
    }
  }

  /// Reverts only the cell this toggle touched, against the *current* matrix —
  /// not a full snapshot rollback, so a different cell that already succeeded
  /// concurrently (e.g. a second rapid toggle) isn't discarded.
  SharingMatrix _revertedMatrix(
    String? recipientId,
    SharedDataType dataType,
    SharingCell? previousCell,
  ) {
    return previousCell == null
        ? _current.matrix.removeCell(recipientId, dataType)
        : _current.matrix.upsert(previousCell);
  }

  Future<void> startTemporaryShare({
    String? recipientId,
    required SharedDataType dataType,
    required Duration duration,
  }) {
    // Capture start and expiry from the same clock read so the total duration
    // (expiresAtUtc - startedAtUtc) is exactly the selected [duration].
    final startedAtUtc = ref.read(privacyNowProvider)().toUtc();
    final expiresAtUtc = startedAtUtc.add(duration);
    return toggle(
      recipientId: recipientId,
      dataType: dataType,
      enabled: true,
      expiresAtUtc: expiresAtUtc,
      startedAtUtc: startedAtUtc,
    );
  }

  Future<String?> exportMyData() async {
    final api = ref.read(privacyApiProvider);
    state = AsyncData(
      _current.copyWith(isExporting: true, clearError: true, clearExport: true),
    );
    try {
      final json = await api.exportMyData();
      state = AsyncData(
        _current.copyWith(
          exportJson: json,
          isExporting: false,
          clearError: true,
        ),
      );
      return json;
    } on PrivacyApiException catch (error) {
      state = AsyncData(
        _current.copyWith(
          isExporting: false,
          error: error.message ?? _exportError,
        ),
      );
      return null;
    } catch (_) {
      state = AsyncData(_current.copyWith(isExporting: false, error: _exportError));
      return null;
    }
  }

  Future<void> deleteMyData() async {
    final api = ref.read(privacyApiProvider);
    state = AsyncData(_current.copyWith(isDeleting: true, clearError: true));
    try {
      await api.deleteMyData();
      ref.invalidate(locationControllerProvider);
      ref.invalidate(historyControllerProvider);
      state = AsyncData(_current.copyWith(isDeleting: false, clearError: true));
    } on PrivacyApiException catch (error) {
      state = AsyncData(
        _current.copyWith(isDeleting: false, error: error.message),
      );
    } catch (_) {
      state = AsyncData(
        _current.copyWith(isDeleting: false, error: 'Something went wrong. Try again.'),
      );
    }
  }
}

final privacyControllerProvider =
    AsyncNotifierProvider<PrivacyController, PrivacyState>(PrivacyController.new);
