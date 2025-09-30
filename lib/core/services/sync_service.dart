import 'dart:convert';
import 'dart:async';
import '../database/database_helper.dart';
import 'network_service.dart';
import '../utils/constants.dart';
import '../../models/media_submission_model.dart';

class SyncService {
  final DatabaseHelper _dbHelper;
  final NetworkService _networkService;
  
  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService(this._dbHelper, this._networkService);

  void startAutoSync() {
    _syncTimer = Timer.periodic(
      Duration(minutes: AppConstants.syncIntervalMinutes),
      (_) => syncPendingData(),
    );
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<SyncResult> syncPendingData() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
      );
    }

    // Check network connectivity
    final isConnected = await _networkService.isConnected();
    if (!isConnected) {
      return SyncResult(
        success: false,
        message: ErrorMessages.networkError,
      );
    }

    _isSyncing = true;

    try {
      int successCount = 0;
      int failureCount = 0;

      // Sync media submissions
      final mediaResult = await _syncMediaSubmissions();
      successCount += mediaResult.successCount;
      failureCount += mediaResult.failureCount;

      // Sync from queue
      final queueResult = await _syncQueue();
      successCount += queueResult.successCount;
      failureCount += queueResult.failureCount;

      _isSyncing = false;

      return SyncResult(
        success: failureCount == 0,
        message: failureCount == 0 
            ? SuccessMessages.syncSuccess 
            : 'Synced $successCount items, $failureCount failed',
        successCount: successCount,
        failureCount: failureCount,
      );
    } catch (e) {
      _isSyncing = false;
      return SyncResult(
        success: false,
        message: 'Sync failed: ${e.toString()}',
      );
    }
  }

  Future<SyncResult> _syncMediaSubmissions() async {
    int successCount = 0;
    int failureCount = 0;

    try {
      // Get pending media submissions
      final pendingMedia = await _dbHelper.query(
        'media_submissions',
        where: 'sync_status = ?',
        whereArgs: ['pending'],
        limit: AppConstants.syncBatchSize,
      );

      for (var mediaMap in pendingMedia) {
        try {
          final media = MediaSubmissionModel.fromMap(mediaMap);
          
          // Upload media file
          final response = await _networkService.uploadMedia(
            filePath: media.filePath,
            metadata: {
              'submission_id': media.submissionId,
              'loan_id': media.loanId,
              'beneficiary_id': media.beneficiaryId,
              'media_type': media.mediaType,
              'latitude': media.latitude,
              'longitude': media.longitude,
              'captured_at': media.capturedAt,
              'description': media.description,
              'asset_category': media.assetCategory,
            },
          );

          if (response.success) {
            // Update sync status
            await _dbHelper.update(
              'media_submissions',
              {
                'sync_status': SyncStatus.synced,
                'server_url': response.data['url'],
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [media.id],
            );
            successCount++;
          } else {
            failureCount++;
            await _updateSyncError(media.id!, response.message ?? 'Upload failed');
          }
        } catch (e) {
          failureCount++;
          print('Failed to sync media: ${e.toString()}');
        }
      }
    } catch (e) {
      print('Error syncing media submissions: ${e.toString()}');
    }

    return SyncResult(
      success: failureCount == 0,
      successCount: successCount,
      failureCount: failureCount,
    );
  }

  Future<SyncResult> _syncQueue() async {
    int successCount = 0;
    int failureCount = 0;

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

          ApiResponse? response;

          switch (entityType) {
            case 'loan':
              if (operation == 'create') {
                response = await _networkService.createLoan(data);
              }
              break;
            case 'approval':
              if (operation == 'update') {
                response = await _networkService.updateSubmissionStatus(
                  submissionId: data['submission_id'],
                  status: data['status'],
                  remarks: data['remarks'],
                );
              }
              break;
          }

          if (response != null && response.success) {
            // Remove from queue
            await _dbHelper.delete(
              'sync_queue',
              where: 'id = ?',
              whereArgs: [item['id']],
            );
            successCount++;
          } else {
            // Increment retry count
            await _dbHelper.update(
              'sync_queue',
              {
                'retry_count': (item['retry_count'] as int) + 1,
                'last_error': response?.message ?? 'Unknown error',
                'attempted_at': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [item['id']],
            );
            failureCount++;
          }
        } catch (e) {
          failureCount++;
          print('Failed to process queue item: ${e.toString()}');
        }
      }
    } catch (e) {
      print('Error syncing queue: ${e.toString()}');
    }

    return SyncResult(
      success: failureCount == 0,
      successCount: successCount,
      failureCount: failureCount,
    );
  }

  Future<void> _updateSyncError(int mediaId, String error) async {
    await _dbHelper.update(
      'media_submissions',
      {
        'sync_status': SyncStatus.failed,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<void> addToSyncQueue({
    required String entityType,
    required int entityId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    await _dbHelper.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'data': jsonEncode(data),
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> getPendingSyncCount() async {
    final mediaCount = await _dbHelper.rawQuery(
      'SELECT COUNT(*) as count FROM media_submissions WHERE sync_status = ?',
      ['pending'],
    );
    
    final queueCount = await _dbHelper.rawQuery(
      'SELECT COUNT(*) as count FROM sync_queue WHERE retry_count < ?',
      [AppConstants.maxRetryAttempts],
    );

    return (mediaCount.first['count'] as int) + (queueCount.first['count'] as int);
  }

  Future<void> retrySyncForFailedItems() async {
    // Reset failed items to pending
    await _dbHelper.update(
      'media_submissions',
      {'sync_status': SyncStatus.pending},
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.failed],
    );

    // Reset retry count for queue items
    await _dbHelper.update(
      'sync_queue',
      {'retry_count': 0},
      where: 'retry_count >= ?',
      whereArgs: [AppConstants.maxRetryAttempts],
    );

    // Trigger sync
    await syncPendingData();
  }
}

class SyncResult {
  final bool success;
  final String? message;
  final int successCount;
  final int failureCount;

  SyncResult({
    required this.success,
    this.message,
    this.successCount = 0,
    this.failureCount = 0,
  });
}
