import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/backup_service.dart';

enum BackupStatus { idle, loading, success, error }

class BackupState {
  final BackupStatus status;
  final String? errorMessage;
  final DateTime? lastBackedAt;

  const BackupState({
    this.status = BackupStatus.idle,
    this.errorMessage,
    this.lastBackedAt,
  });

  BackupState copyWith({
    BackupStatus? status,
    String? errorMessage,
    DateTime? lastBackedAt,
  }) {
    return BackupState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      lastBackedAt: lastBackedAt ?? this.lastBackedAt,
    );
  }

  bool get isLoading => status == BackupStatus.loading;
}

class BackupNotifier extends StateNotifier<BackupState> {
  BackupNotifier() : super(const BackupState()) {
    _loadLastBackup();
  }

  final _service = BackupService();

  void _loadLastBackup() {
    final last = _service.lastBackupTime;
    if (last != null) {
      state = state.copyWith(lastBackedAt: last);
    }
  }

  Future<void> backup() async {
    state = state.copyWith(status: BackupStatus.loading);
    try {
      await _service.upload();
      state = BackupState(
        status: BackupStatus.success,
        lastBackedAt: _service.lastBackupTime,
      );
    } catch (e) {
      state = state.copyWith(
        status: BackupStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void resetStatus() {
    state = state.copyWith(status: BackupStatus.idle);
  }
}

final backupProvider =
    StateNotifierProvider<BackupNotifier, BackupState>((ref) {
  return BackupNotifier();
});
