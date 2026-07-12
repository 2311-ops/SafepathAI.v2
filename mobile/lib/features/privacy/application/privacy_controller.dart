import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../family/application/family_controller.dart';
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
    }
  }

  Future<void> toggle({
    String? recipientId,
    required SharedDataType dataType,
    required bool enabled,
    DateTime? expiresAtUtc,
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
          matrix: _current.matrix.upsert(updated),
          clearError: true,
        ),
      );
    } on PrivacyApiException catch (error) {
      state = AsyncData(
        before.copyWith(error: error.message ?? _saveSettingError),
      );
    } catch (_) {
      state = AsyncData(before.copyWith(error: _saveSettingError));
    }
  }

  Future<void> startTemporaryShare({
    String? recipientId,
    required SharedDataType dataType,
    required Duration duration,
  }) {
    final expiresAtUtc = ref.read(privacyNowProvider)().add(duration).toUtc();
    return toggle(
      recipientId: recipientId,
      dataType: dataType,
      enabled: true,
      expiresAtUtc: expiresAtUtc,
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
      state = AsyncData(_current.copyWith(isDeleting: false, clearError: true));
    } on PrivacyApiException catch (error) {
      state = AsyncData(
        _current.copyWith(isDeleting: false, error: error.message),
      );
    }
  }
}

final privacyControllerProvider =
    AsyncNotifierProvider<PrivacyController, PrivacyState>(PrivacyController.new);
