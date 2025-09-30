# Offline Support & Sync Implementation Guide

## Overview
This guide explains the comprehensive offline support and Firebase Firestore integration for the Loan Utilization App, including role-based report persistence and conflict resolution.

## Architecture

### 1. **Three-Tier Data Storage**
```
┌─────────────────────────────────────┐
│   Firebase Firestore (Cloud)       │
│   - Master database                 │
│   - Real-time sync                  │
│   - Offline persistence enabled     │
└─────────────────────────────────────┘
              ↕ Sync
┌─────────────────────────────────────┐
│   Local SQLite Database             │
│   - Immediate read/write            │
│   - Offline-first operations        │
│   - Sync queue management           │
└─────────────────────────────────────┘
              ↕ Cache
┌─────────────────────────────────────┐
│   Secure Storage                    │
│   - User session                    │
│   - Authentication tokens           │
│   - App preferences                 │
└─────────────────────────────────────┘
```

### 2. **Role-Based Data Access**
```
Field Officer Role:
  ✓ Create loan utilization reports
  ✓ Upload media (photos/videos) with GPS
  ✓ View own submissions
  ✓ Update pending submissions
  ✗ Cannot approve/reject

Reviewer Role:
  ✓ View all submissions from field officers
  ✓ Add comments and review notes
  ✓ Request more information
  ✓ View history and audit trails
  ✗ Cannot final approve (limited authority)

Admin Role:
  ✓ All reviewer permissions
  ✓ Final approve/reject submissions
  ✓ Override lower authority decisions
  ✓ Access analytics and reports
  ✓ Manage users and roles
```

## Features Implemented

### 1. **Offline Support**

#### Local Database (SQLite)
- All CRUD operations work offline
- Data persists across app restarts
- Sync status tracking for each record
- Conflict detection metadata

#### Offline Capabilities
✓ Create loan records
✓ Upload media files (stored locally)
✓ Add comments and reviews
✓ Update submission status
✓ View historical data
✓ Search and filter records

#### Sync Queue Management
```dart
// Automatic queuing of offline operations
{
  "entity_type": "media",
  "entity_id": 123,
  "operation": "create",
  "data": {...},
  "retry_count": 0,
  "created_at": timestamp,
  "user_id": 456,
  "user_role": "officer"
}
```

### 2. **Firebase Firestore Integration**

#### Collections Structure
```
firestore/
├── users/
│   └── {userId}/
│       ├── profile
│       ├── role
│       └── permissions
├── loans/
│   └── {loanId}/
│       ├── details
│       ├── beneficiary_id
│       ├── officer_id
│       └── status
├── media_submissions/
│   └── {submissionId}/
│       ├── loan_id
│       ├── beneficiary_id
│       ├── file_url
│       ├── metadata
│       ├── status
│       ├── created_by
│       ├── reviewed_by
│       └── review_history[]
└── sync_logs/
    └── {logId}/
        ├── entity_type
        ├── operation
        ├── timestamp
        └── user_id
```

#### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function getUserRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }
    
    function isOfficer() {
      return getUserRole() == 'officer';
    }
    
    function isReviewer() {
      return getUserRole() in ['reviewer', 'admin'];
    }
    
    function isAdmin() {
      return getUserRole() == 'admin';
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated() && request.auth.uid == userId;
      allow write: if isAdmin();
    }
    
    // Loans collection
    match /loans/{loanId} {
      allow read: if isAuthenticated();
      allow create: if isOfficer();
      allow update: if isReviewer() || (isOfficer() && resource.data.officer_id == request.auth.uid);
      allow delete: if isAdmin();
    }
    
    // Media submissions
    match /media_submissions/{submissionId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update: if isReviewer() || 
                       (isOfficer() && resource.data.created_by == request.auth.uid && 
                        resource.data.status == 'pending');
      allow delete: if isAdmin();
    }
    
    // Sync logs
    match /sync_logs/{logId} {
      allow read, write: if isAuthenticated();
    }
  }
}
```

### 3. **Offline Persistence Configuration**

#### Enable Firestore Offline Persistence
```dart
final firestore = FirebaseFirestore.instance;

// Enable offline persistence
await firestore.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);

// Enable network first, fall back to cache
firestore.enableNetwork();
```

### 4. **Synchronization Strategy**

#### Conflict Resolution Rules
Priority hierarchy (highest to lowest):
1. **Admin** - Can override any previous decision
2. **Reviewer** - Can update officer submissions
3. **Officer** - Can only update own pending submissions
4. **Timestamp** - Most recent update wins if same authority level

#### Conflict Detection
```dart
class ConflictDetector {
  ConflictResolution detectConflict({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> remoteData,
    required String userRole,
  }) {
    // Get timestamps
    final localUpdated = localData['updated_at'];
    final remoteUpdated = remoteData['updated_at'];
    
    // Get authority levels
    final localAuthority = getAuthorityLevel(localData['updated_by_role']);
    final remoteAuthority = getAuthorityLevel(remoteData['updated_by_role']);
    
    // Authority-based resolution
    if (remoteAuthority > localAuthority) {
      return ConflictResolution.useRemote;
    } else if (localAuthority > remoteAuthority) {
      return ConflictResolution.useLocal;
    } else {
      // Same authority - use timestamp
      return remoteUpdated > localUpdated 
          ? ConflictResolution.useRemote 
          : ConflictResolution.useLocal;
    }
  }
  
  int getAuthorityLevel(String role) {
    switch (role) {
      case 'admin': return 3;
      case 'reviewer': return 2;
      case 'officer': return 1;
      default: return 0;
    }
  }
}
```

#### Sync Flow
```
1. User Action (Offline/Online)
   ↓
2. Save to Local SQLite
   ↓
3. Mark as 'pending' in sync_status
   ↓
4. Add to sync_queue with user context
   ↓
5. Background Sync Service (triggered by):
   - Network availability change
   - Periodic timer (15 min)
   - Manual user refresh
   ↓
6. Process Sync Queue
   - Check network
   - Batch operations (10 at a time)
   - Upload media files first
   - Then update metadata
   ↓
7. Conflict Detection
   - Compare local vs Firestore
   - Apply resolution rules
   - Merge or override
   ↓
8. Update Local Database
   - Mark as 'synced'
   - Remove from queue
   - Update UI
   ↓
9. Firebase Listeners (when online)
   - Real-time updates from other users
   - Auto-merge with local data
   - Notify user of changes
```

### 5. **User Experience Enhancements**

#### Connection Status Indicator
```dart
// Top app bar indicator
Widget _buildConnectionStatus(bool isOnline) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: isOnline ? Colors.green : Colors.orange,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOnline ? Icons.cloud_done : Icons.cloud_off,
          size: 16,
          color: Colors.white,
        ),
        SizedBox(width: 4),
        Text(
          isOnline ? 'Online' : 'Offline',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
```

#### Sync Status Badges
```dart
// On each submission card
Widget _buildSyncStatusBadge(String syncStatus) {
  Color color;
  IconData icon;
  String label;
  
  switch (syncStatus) {
    case 'pending':
      color = Colors.orange;
      icon = Icons.cloud_upload;
      label = 'Pending Sync';
      break;
    case 'synced':
      color = Colors.green;
      icon = Icons.cloud_done;
      label = 'Synced';
      break;
    case 'failed':
      color = Colors.red;
      icon = Icons.cloud_off;
      label = 'Sync Failed';
      break;
    default:
      color = Colors.grey;
      icon = Icons.help_outline;
      label = 'Unknown';
  }
  
  return Chip(
    avatar: Icon(icon, size: 16, color: color),
    label: Text(label),
    backgroundColor: color.withOpacity(0.1),
    labelStyle: TextStyle(color: color, fontSize: 11),
  );
}
```

#### Sync Progress Notification
```dart
// Bottom sheet during sync
void _showSyncProgress(BuildContext context, SyncProgress progress) {
  showModalBottomSheet(
    context: context,
    isDismissible: false,
    builder: (context) => Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Syncing Data...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            '${progress.completed}/${progress.total} items',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress.completed / progress.total,
          ),
        ],
      ),
    ),
  );
}
```

### 6. **Report Persistence by User Role**

#### Data Tagging
Every record includes:
```dart
{
  "id": "...",
  "created_by": userId,
  "created_by_role": userRole,
  "created_at": timestamp,
  "updated_by": userId,
  "updated_by_role": userRole,
  "updated_at": timestamp,
  "sync_status": "pending|synced|failed",
  "sync_attempts": 0,
  "last_sync_error": null,
}
```

#### Role-Specific Queries
```dart
// Field Officer - View own submissions
await db.query(
  'media_submissions',
  where: 'beneficiary_id = ? OR created_by = ?',
  whereArgs: [currentUser.id, currentUser.id],
);

// Reviewer - View all submissions
await db.query('media_submissions');

// Admin - View all with filters
await db.query(
  'media_submissions',
  where: 'status IN (?, ?, ?)',
  whereArgs: ['pending', 'under_review', 'approved'],
);
```

### 7. **Session Management**

#### Secure Session Storage
```dart
class SessionManager {
  static Future<void> saveSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_role', user.role);
    await prefs.setString('user_name', user.fullName);
    await prefs.setInt('session_start', DateTime.now().millisecondsSinceEpoch);
  }
  
  static Future<UserSession?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    
    if (userId == null) return null;
    
    return UserSession(
      userId: userId,
      userRole: prefs.getString('user_role')!,
      userName: prefs.getString('user_name')!,
      sessionStart: prefs.getInt('session_start')!,
    );
  }
  
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
```

### 8. **Testing Offline Mode**

#### Simulate Offline Behavior
1. **Airplane Mode**: Enable airplane mode on device
2. **Network Throttling**: Use Android Studio's network profiler
3. **Manual Toggle**: Add dev setting to simulate offline mode

#### Test Scenarios
✓ Create records while offline
✓ Edit existing records offline
✓ View cached data offline
✓ Switch to online and verify sync
✓ Conflict resolution with multiple users
✓ Retry failed syncs
✓ Handle partial sync failures

### 9. **Performance Optimization**

#### Batch Operations
```dart
// Sync in batches to avoid overwhelming the network
const BATCH_SIZE = 10;
final pendingItems = await getPendingSync();

for (var i = 0; i < pendingItems.length; i += BATCH_SIZE) {
  final batch = pendingItems.skip(i).take(BATCH_SIZE);
  await syncBatch(batch);
  await Future.delayed(Duration(seconds: 2)); // Rate limiting
}
```

#### Incremental Sync
```dart
// Only sync changed data since last sync
final lastSyncTime = await getLastSyncTimestamp();

await firestore
  .collection('media_submissions')
  .where('updated_at', isGreaterThan: lastSyncTime)
  .get();
```

#### Media File Compression
```dart
// Compress images before upload
final compressedImage = await FlutterImageCompress.compressAndGetFile(
  originalFile.path,
  targetPath,
  quality: 85,
  minWidth: 1920,
  minHeight: 1080,
);
```

## Monitoring & Debugging

### Sync Status Dashboard
```dart
class SyncStatusWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SyncStats>(
      future: getSyncStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final stats = snapshot.data!;
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatRow('Pending', stats.pending, Colors.orange),
                _buildStatRow('Synced', stats.synced, Colors.green),
                _buildStatRow('Failed', stats.failed, Colors.red),
                ElevatedButton(
                  onPressed: () => retryFailedSyncs(),
                  child: Text('Retry Failed'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

### Audit Trail
Every sync operation is logged:
```dart
await db.insert('audit_logs', {
  'user_id': currentUser.id,
  'action': 'sync_media',
  'entity_type': 'media_submission',
  'entity_id': mediaId,
  'details': jsonEncode({
    'sync_status': 'success',
    'items_synced': 1,
    'duration_ms': 1234,
  }),
  'created_at': DateTime.now().millisecondsSinceEpoch,
});
```

## Troubleshooting

### Common Issues

**Issue**: Sync stuck in pending
**Solution**: 
1. Check network connectivity
2. Verify Firebase configuration
3. Check Firestore security rules
4. Review error logs in sync_queue table

**Issue**: Conflicts not resolving
**Solution**:
1. Verify user roles are correctly set
2. Check conflict detection logic
3. Manually resolve via admin panel

**Issue**: Slow sync performance
**Solution**:
1. Enable batch operations
2. Compress media files
3. Reduce sync batch size
4. Implement pagination

## Best Practices

1. **Always save locally first** - Never wait for network
2. **Show clear status indicators** - User should know sync state
3. **Handle failures gracefully** - Retry with exponential backoff
4. **Test offline scenarios** - Use automated tests
5. **Monitor sync metrics** - Track success rates
6. **Implement proper logging** - Debug issues quickly
7. **Respect user's data plan** - Sync on WiFi when possible
8. **Secure sensitive data** - Encrypt before storing

## Future Enhancements

- [ ] Background sync worker
- [ ] Delta sync (only changed fields)
- [ ] P2P sync between devices
- [ ] Offline AI validation
- [ ] Predictive pre-fetching
- [ ] Selective sync options
- [ ] Bandwidth optimization
