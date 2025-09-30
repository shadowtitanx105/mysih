import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/connectivity_provider.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/utils/constants.dart';

/// Displays connection status with visual indicators
class ConnectionStatusWidget extends StatelessWidget {
  final bool showLabel;
  final bool showSyncButton;
  final bool compact;

  const ConnectionStatusWidget({
    Key? key,
    this.showLabel = true,
    this.showSyncButton = true,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityProvider, SyncProvider>(
      builder: (context, connectivityProvider, syncProvider, _) {
        final isOnline = connectivityProvider.isOnline;
        final isSyncing = syncProvider.isSyncing;
        final pendingCount = syncProvider.pendingCount;

        if (compact) {
          return _buildCompactView(isOnline, isSyncing, pendingCount);
        }

        return _buildFullView(
          context,
          isOnline,
          isSyncing,
          pendingCount,
          syncProvider,
        );
      },
    );
  }

  Widget _buildCompactView(bool isOnline, bool isSyncing, int pendingCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(isOnline, isSyncing).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(isOnline, isSyncing),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(isOnline, isSyncing),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              _getStatusText(isOnline, isSyncing, pendingCount),
              style: TextStyle(
                color: _getStatusColor(isOnline, isSyncing),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFullView(
    BuildContext context,
    bool isOnline,
    bool isSyncing,
    int pendingCount,
    SyncProvider syncProvider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatusIcon(isOnline, isSyncing),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getStatusText(isOnline, isSyncing, pendingCount),
                  style: TextStyle(
                    color: _getStatusColor(isOnline, isSyncing),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (pendingCount > 0 && !isSyncing) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$pendingCount ${pendingCount == 1 ? 'item' : 'items'} pending sync',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (syncProvider.lastSyncTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last synced: ${_formatLastSync(syncProvider.lastSyncTime!)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showSyncButton && isOnline && pendingCount > 0 && !isSyncing)
            IconButton(
              onPressed: () => syncProvider.syncNow(),
              icon: const Icon(Icons.sync, color: AppColors.primaryColor),
              tooltip: 'Sync now',
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool isOnline, bool isSyncing) {
    if (isSyncing) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor:
              AlwaysStoppedAnimation<Color>(AppColors.syncPending),
        ),
      );
    }

    return Icon(
      isOnline ? Icons.cloud_done : Icons.cloud_off,
      color: _getStatusColor(isOnline, isSyncing),
      size: 20,
    );
  }

  Color _getStatusColor(bool isOnline, bool isSyncing) {
    if (isSyncing) return AppColors.syncPending;
    return isOnline ? AppColors.syncSynced : AppColors.syncFailed;
  }

  String _getStatusText(bool isOnline, bool isSyncing, int pendingCount) {
    if (isSyncing) return 'Syncing...';
    if (!isOnline) return 'Offline';
    if (pendingCount > 0) return 'Online (Pending)';
    return 'Online';
  }

  String _formatLastSync(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

/// Shows connection status as an app bar banner
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, provider, _) {
        if (provider.isOnline) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.warningColor,
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'You are offline. Changes will sync when online.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Floating action button for manual sync
class SyncFloatingActionButton extends StatelessWidget {
  const SyncFloatingActionButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityProvider, SyncProvider>(
      builder: (context, connectivityProvider, syncProvider, _) {
        if (!connectivityProvider.isOnline || syncProvider.pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.extended(
          onPressed: syncProvider.isSyncing ? null : () => syncProvider.syncNow(),
          icon: syncProvider.isSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.sync),
          label: Text(
            syncProvider.isSyncing
                ? 'Syncing...'
                : 'Sync ${syncProvider.pendingCount}',
          ),
          backgroundColor:
              syncProvider.isSyncing ? Colors.grey : AppColors.primaryColor,
        );
      },
    );
  }
}

/// Bottom sheet showing sync progress
class SyncProgressSheet extends StatelessWidget {
  const SyncProgressSheet({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => const SyncProgressSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, _) {
        if (!syncProvider.isSyncing) {
          Navigator.of(context).pop();
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Syncing Data',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                syncProvider.lastSyncMessage ?? 'Please wait...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              if (syncProvider.pendingCount > 0) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${syncProvider.pendingCount} items remaining',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
