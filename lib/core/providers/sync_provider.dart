import 'package:flutter/foundation.dart';
import '../services/sync_service.dart';

class SyncProvider with ChangeNotifier {
  final SyncService _syncService;
  
  bool _isSyncing = false;
  int _pendingCount = 0;
  String? _lastSyncMessage;
  DateTime? _lastSyncTime;

  SyncProvider(this._syncService) {
    _initSync();
  }

  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  String? get lastSyncMessage => _lastSyncMessage;
  DateTime? get lastSyncTime => _lastSyncTime;

  void _initSync() {
    _syncService.startAutoSync();
    updatePendingCount();
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _syncService.syncPendingData();
      _lastSyncMessage = result.message;
      _lastSyncTime = DateTime.now();
      await updatePendingCount();
    } catch (e) {
      _lastSyncMessage = 'Sync failed: ${e.toString()}';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> updatePendingCount() async {
    _pendingCount = await _syncService.getPendingSyncCount();
    notifyListeners();
  }

  Future<void> retryFailedSyncs() async {
    await _syncService.retrySyncForFailedItems();
    await updatePendingCount();
  }

  void dispose() {
    _syncService.stopAutoSync();
    super.dispose();
  }
}
