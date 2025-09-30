import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import 'firebase_service.dart';
import 'network_service.dart';
import '../utils/constants.dart';
import '../../models/media_submission_model.dart';
import '../../models/loan_model.dart';

/// Enhanced Sync Service with Firebase Firestore integration
/// Handles offline operations, conflict resolution, and role-based sync
class EnhancedSyncService {
  final DatabaseHelper _dbHelper;
  final FirebaseService _firebaseService;
  final NetworkService _networkService;

  Timer? _syncTimer;
  bool _isSyncing = false;
  final _syncStatusController = StreamController<SyncStatusInfo>.broadcast();

  // Track connectivity
  StreamSubscription? _connectivitySubscription;
  bool _isOnline = false;

  EnhancedSyncService(
    this._dbHelper,
    this._firebaseService,
    this._networkService,
  ) {
    _initConnectivityListener();
  }

  Stream<SyncStatusInfo> get syncStatusStream => _syncStatusController.stream;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  /// Initialize connectivity listener
  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) async {
        final wasOffline = !_isOnline;
        _isOnline = result != ConnectivityResult.none;

        _syncStatusController.add(SyncStatusInfo.connectionChanged(_isOnline));

        // If coming back online, trigger sync
        if (wasOffline && _isOnline) {
          print('Network connection restored. Triggering sync...');
          await Future.delayed(Duration(seconds: 2));
          await syncPendingData();
        }
      },
    );

    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    _syncStatusController.add(SyncStatusInfo.connectionChanged(_isOnline));
  }

  /// Start automatic background sync
  void startAutoSync() {
    _syncTimer = Timer.periodic(
      Duration(minutes: AppConstants.syncIntervalMinutes),
      (_) => syncPendingData(),
    );
    print(
        'Auto-sync started (every ${AppConstants.syncIntervalMinutes} minutes)');
  }

  /// Stop automatic sync
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('Auto-sync stopped');
  }

  /// Main sync operation
  Future<SyncResult> syncPendingData() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
      );
    }

    _isOnline = await _networkService.isConnected();
    if (!_isOnline) {
      _syncStatusController.add(SyncStatusInfo.offline());
      return SyncResult(
        success: false,
        message: ErrorMessages.networkError,
      );
    }

    _isSyncing = true;
    _syncStatusController.add(SyncStatusInfo.syncing(0, 0, 'Starting sync...'));

    try {
      int successCount = 0;
      int failureCount = 0;
      List<String> errors = [];

      // Sync media files
      _syncStatusController
          .add(SyncStatusInfo.syncing(0, 0, 'Uploading media...'));
      final mediaResult = await _syncMediaSubmissions();
      successCount += mediaResult.successCount;
      failureCount += mediaResult.failureCount;
      if (mediaResult.errors != null) errors.addAll(mediaResult.errors!);

      // Sync loans
      _syncStatusController.add(SyncStatusInfo.syncing(
          successCount, failureCount, 'Syncing loans...'));
      final loanResult = await _syncLoans();
      successCount += loanResult.successCount;
      failureCount += loanResult.failureCount;
      if (loanResult.errors != null) errors.addAll(loanResult.errors!);

      // Sync queue
      _syncStatusController.add(SyncStatusInfo.syncing(
          successCount, failureCount, 'Processing queue...'));
      final queueResult = await _syncQueue();
      successCount += queueResult.successCount;
      failureCount += queueResult.failureCount;
      if (queueResult.errors != null) errors.addAll(queueResult.errors!);

      // Pull remote updates
      _syncStatusController.add(SyncStatusInfo.syncing(
          successCount, failureCount, 'Fetching updates...'));
      await _pullRemoteUpdates();

      _isSyncing = false;

      final result = SyncResult(
        success: failureCount == 0,
        message: failureCount == 0
            ? SuccessMessages.syncSuccess
            : 'Synced $successCount items, $failureCount failed',
        successCount: successCount,
        failureCount: failureCount,
        errors: errors.isEmpty ? null : errors,
      );

      _syncStatusController.add(
        failureCount == 0
            ? SyncStatusInfo.completed(successCount)
            : SyncStatusInfo.completedWithErrors(successCount, failureCount),
      );

      return result;
    } catch (e) {
      _isSyncing = false;
      _syncStatusController.add(SyncStatusInfo.error(e.toString()));
      return SyncResult(success: false, message: 'Sync failed: $e');
    }
  }

  /// Sync media submissions
  Future<SyncResult> _syncMediaSubmissions() async {
    int successCount = 0;
    int failureCount = 0;
    List<String> errors = [];

    try {
      final pendingMedia = await _dbHelper.query(
        'media_submissions',
        where: 'sync_status = ? AND sync_attempts < ?',
        whereArgs: [SyncStatus.pending, AppConstants.maxRetryAttempts],
        limit: AppConstants.syncBatchSize,
      );

      for (var mediaMap in pendingMedia) {
        try {
          final media = MediaSubmissionModel.fromMap(mediaMap);
          final userId = mediaMap['created_by'].toString();
          final userRole = mediaMap['created_by_role'] as String;

          // Upload file if needed
          String? fileUrl = media.serverUrl;
          if (fileUrl == null) {
            final file = File(media.filePath);
            if (await file.exists()) {
              fileUrl = await _firebaseService.uploadMediaFile(
                file,
                media.submissionId,
                media.mediaType,
              );
            }
          }

          if (fileUrl == null) throw Exception('Failed to upload file');

          // Handle conflicts
          String? firestoreId = mediaMap['firestore_id'] as String?;
          if (firestoreId != null) {
            final remoteDoc = await _firebaseService._firestore
                .collection('media_submissions')
                .doc(firestoreId)
                .get();

            final conflict = await _firebaseService.detectConflict(
              localData: mediaMap,
              remoteDoc: remoteDoc,
              userRole: userRole,
            );

            if (conflict.action == ConflictAction.useRemote) {
              await _updateLocalFromRemote('media_submissions',
                  mediaMap['id'] as int, conflict.mergedData!);
              successCount++;
              continue;
            }
          }

          // Create/update in Firestore
          final updatedMedia = media.copyWith(serverUrl: fileUrl);
          firestoreId = firestoreId ??
              await _firebaseService.createMediaSubmission(
                updatedMedia,
                userId,
                userRole,
              );

          if (firestoreId != null) {
            await _dbHelper.update(
              'media_submissions',
              {
                'sync_status': SyncStatus.synced,
                'server_url': fileUrl,
                'firestore_id': firestoreId,
                'sync_attempts': 0,
                'last_sync_error': null,
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [media.id],
            );
            successCount++;

            await _firebaseService.logSyncOperation(
              entityType: 'media',
              operation: 'sync',
              userId: userId,
              userRole: userRole,
              success: true,
            );
          }
        } catch (e) {
          failureCount++;
          errors.add('Media sync error: $e');
          await _updateSyncError(
              'media_submissions', mediaMap['id'] as int, e.toString());
        }
      }
    } catch (e) {
      errors.add('Media sync failed: $e');
    }

    return SyncResult(
      success: failureCount == 0,
      successCount: successCount,
      failureCount: failureCount,
      errors: errors.isEmpty ? null : errors,
    );
  }

  /// Sync loans
  Future<SyncResult> _syncLoans() async {
    int successCount = 0;
    int failureCount = 0;
    List<String> errors = [];

    try {
      final pendingLoans = await _dbHelper.query(
        'loans',
        where: 'sync_status = ? AND sync_attempts < ?',
        whereArgs: [SyncStatus.pending, AppConstants.maxRetryAttempts],
        limit: AppConstants.syncBatchSize,
      );

      for (var loanMap in pendingLoans) {
        try {
          final loan = LoanModel.fromMap(loanMap);
          final userId = loanMap['created_by'].toString();
          final userRole = loanMap['created_by_role'] as String;

          String? firestoreId = loanMap['firestore_id'] as String?;
          if (firestoreId != null) {
            final remoteDoc = await _firebaseService._firestore
                .collection('loans')
                .doc(firestoreId)
                .get();

            final conflict = await _firebaseService.detectConflict(
              localData: loanMap,
              remoteDoc: remoteDoc,
              userRole: userRole,
            );

            if (conflict.action == ConflictAction.useRemote) {
              await _updateLocalFromRemote(
                  'loans', loanMap['id'] as int, conflict.mergedData!);
              successCount++;
              continue;
            }
          }

          firestoreId = firestoreId ??
              await _firebaseService.createLoan(loan, userId, userRole);

          if (firestoreId != null) {
            await _dbHelper.update(
              'loans',
              {
                'sync_status': SyncStatus.synced,
                'firestore_id': firestoreId,
                'sync_attempts': 0,
                'last_sync_error': null,
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [loan.id],
            );
            successCount++;

            await _firebaseService.logSyncOperation(
              entityType: 'loan',
              operation: 'sync',
              userId: userId,
              userRole: userRole,
              success: true,
            );
          }
        } catch (e) {
          failureCount++;
          errors.add('Loan sync error: $e');
          await _updateSyncError('loans', loanMap['id'] as int, e.toString());
        }
      }
    } catch (e) {
      errors.add('Loan sync failed: $e');
    }

    return SyncResult(
      success: failureCount == 0,
      successCount: successCount,
      failureCount: failureCount,
      errors: errors.isEmpty ? null : errors,
    );
  }

  /// Process sync queue
  Future<SyncResult> _syncQueue() async {
    int successCount = 0;
    int failureCount = 0;
    List<String> errors = [];

    try {
      final queueItems = await _dbHelper.query(
        'sync_queue',
        where: 'retry_count < ?',
        whereArgs: [AppConstants.maxRetryAttempts],
        orderBy: 'created_at ASC',
        limit: AppConstants.syncBatchSize,
      );

      for (var item in queueItems) {
        try {
          final entityType = item['entity_type'] as String;
          final operation = item['operation'] as String;
          final data = jsonDecode(item['data'] as String);
          final userId = item['user_id'].toString();
          final userRole = item['user_role'] as String;

          bool success = false;

          if (entityType == 'approval' && operation == 'update') {
            success = await _firebaseService.updateSubmissionStatus(
              data['firestore_id'],
              data['status'],
              data['remarks'] ?? '',
              userId,
              userRole,
            );
          }

          if (success) {
            await _dbHelper
                .delete('sync_queue', where: 'id = ?', whereArgs: [item['id']]);
            successCount++;
          } else {
            await _dbHelper.update(
              'sync_queue',
              {
                'retry_count': (item['retry_count'] as int) + 1,
                'last_error': 'Sync failed',
                'attempted_at': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [item['id']],
            );
            failureCount++;
          }
        } catch (e) {
          failureCount++;
          errors.add('Queue item error: $e');
        }
      }
    } catch (e) {
      errors.add('Queue sync failed: $e');
    }

    return SyncResult(
      success: failureCount == 0,
      successCount: successCount,
      failureCount: failureCount,
      errors: errors.isEmpty ? null : errors,
    );
  }

  /// Pull remote updates from Firestore
  Future<void> _pullRemoteUpdates() async {
    // This would listen to Firestore snapshots and update local DB
    // Implementation depends on specific requirements
  }

  /// Update local record from remote data
  Future<void> _updateLocalFromRemote(
    String table,
    int localId,
    Map<String, dynamic> remoteData,
  ) async {
    await _dbHelper.update(
      table,
      {
        ...remoteData,
        'sync_status': SyncStatus.synced,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Update sync error
  Future<void> _updateSyncError(String table, int id, String error) async {
    await _dbHelper.update(
      table,
      {
        'sync_status': SyncStatus.failed,
        'sync_attempts': await _getSyncAttempts(table, id) + 1,
        'last_sync_error': error,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> _getSyncAttempts(String table, int id) async {
    final results =
        await _dbHelper.query(table, where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty
        ? (results.first['sync_attempts'] as int? ?? 0)
        : 0;
  }

  /// Add item to sync queue
  Future<void> addToSyncQueue({
    required String entityType,
    required int entityId,
    required String operation,
    required Map<String, dynamic> data,
    required int userId,
    required String userRole,
  }) async {
    await _dbHelper.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'data': jsonEncode(data),
      'user_id': userId,
      'user_role': userRole,
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Get pending sync count
  Future<int> getPendingSyncCount() async {
    final mediaCount = await _dbHelper.rawQuery(
      'SELECT COUNT(*) as count FROM media_submissions WHERE sync_status = ?',
      [SyncStatus.pending],
    );

    final loanCount = await _dbHelper.rawQuery(
      'SELECT COUNT(*) as count FROM loans WHERE sync_status = ?',
      [SyncStatus.pending],
    );

    final queueCount = await _dbHelper.rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue WHERE retry_count < ?',
      [AppConstants.maxRetryAttempts],
    );

    return (mediaCount.first['count'] as int) +
        (loanCount.first['count'] as int) +
        (queueCount.first['count'] as int);
  }

  /// Retry failed syncs
  Future<void> retrySyncForFailedItems() async {
    await _dbHelper.update(
      'media_submissions',
      {'sync_status': SyncStatus.pending, 'sync_attempts': 0},
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.failed],
    );

    await _dbHelper.update(
      'loans',
      {'sync_status': SyncStatus.pending, 'sync_attempts': 0},
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.failed],
    );

    await _dbHelper.update(
      'sync_queue',
      {'retry_count': 0},
      where: 'retry_count >= ?',
      whereArgs: [AppConstants.maxRetryAttempts],
    );
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
  }
}
