class SyncResult {
  final bool success;
  final String? message;
  final int successCount;
  final int failureCount;
  final List<String>? errors;

  const SyncResult({
    required this.success,
    this.message,
    this.successCount = 0,
    this.failureCount = 0,
    this.errors,
  });
}

class SyncStatusInfo {
  final bool isOnline;
  final bool isSyncing;
  final int successCount;
  final int failureCount;
  final String? message;
  final SyncPhase phase;

  const SyncStatusInfo._({
    required this.isOnline,
    required this.isSyncing,
    required this.successCount,
    required this.failureCount,
    required this.phase,
    this.message,
  });

  factory SyncStatusInfo.connectionChanged(bool online) => SyncStatusInfo._(
        isOnline: online,
        isSyncing: false,
        successCount: 0,
        failureCount: 0,
        phase: online ? SyncPhase.idle : SyncPhase.offline,
        message: online ? 'Online' : 'Offline',
      );

  factory SyncStatusInfo.offline() => SyncStatusInfo._(
        isOnline: false,
        isSyncing: false,
        successCount: 0,
        failureCount: 0,
        phase: SyncPhase.offline,
        message: 'Offline',
      );

  factory SyncStatusInfo.syncing(int success, int failure, String msg) =>
      SyncStatusInfo._(
        isOnline: true,
        isSyncing: true,
        successCount: success,
        failureCount: failure,
        phase: SyncPhase.syncing,
        message: msg,
      );

  factory SyncStatusInfo.completed(int success) => SyncStatusInfo._(
        isOnline: true,
        isSyncing: false,
        successCount: success,
        failureCount: 0,
        phase: SyncPhase.completed,
        message: 'Sync completed',
      );

  factory SyncStatusInfo.completedWithErrors(int success, int failure) =>
      SyncStatusInfo._(
        isOnline: true,
        isSyncing: false,
        successCount: success,
        failureCount: failure,
        phase: SyncPhase.completedWithErrors,
        message: 'Completed with errors',
      );

  factory SyncStatusInfo.error(String msg) => SyncStatusInfo._(
        isOnline: true,
        isSyncing: false,
        successCount: 0,
        failureCount: 0,
        phase: SyncPhase.error,
        message: msg,
      );
}

enum SyncPhase { idle, offline, syncing, completed, completedWithErrors, error }
