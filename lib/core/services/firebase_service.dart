import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../../models/user_model.dart';
import '../../models/loan_model.dart';
import '../../models/media_submission_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DatabaseHelper _dbHelper;

  FirebaseService(this._dbHelper);

  // Expose Firestore for read-only access where needed
  FirebaseFirestore get firestore => _firestore;

  /// Initialize Firebase with offline persistence
  Future<void> initialize() async {
    try {
      // Enable offline persistence
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Enable network
      await _firestore.enableNetwork();

      print('Firebase initialized with offline persistence');
    } catch (e) {
      print('Error initializing Firebase: $e');
    }
  }

  /// Get current Firebase user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return _auth.currentUser != null;
  }

  // ==================== USER MANAGEMENT ====================

  /// Sync user profile to Firestore
  Future<void> syncUserProfile(UserModel user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.id.toString());

      await userRef.set({
        'mobile_number': user.mobileNumber,
        'full_name': user.fullName,
        'email': user.email,
        'role': user.role,
        'is_verified': user.isVerified,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'last_active': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('User profile synced to Firestore');
    } catch (e) {
      print('Error syncing user profile: $e');
      rethrow;
    }
  }

  /// Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// Listen to user profile changes
  Stream<DocumentSnapshot> listenToUserProfile(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // ==================== LOAN MANAGEMENT ====================

  /// Create loan in Firestore
  Future<String?> createLoan(
      LoanModel loan, String userId, String userRole) async {
    try {
      final loanRef = _firestore.collection('loans').doc();

      await loanRef.set({
        'loan_id': loan.loanId,
        'beneficiary_id': loan.beneficiaryId,
        'officer_id': loan.officerId,
        'loan_amount': loan.loanAmount,
        'loan_purpose': loan.loanPurpose,
        'scheme_name': loan.schemeName,
        'sanctioned_date':
            Timestamp.fromMillisecondsSinceEpoch(loan.sanctionedDate),
        'disbursed_date': loan.disbursedDate != null
            ? Timestamp.fromMillisecondsSinceEpoch(loan.disbursedDate!)
            : null,
        'status': loan.status,
        'remarks': loan.remarks,
        'created_by': userId,
        'created_by_role': userRole,
        'created_at': FieldValue.serverTimestamp(),
        'updated_by': userId,
        'updated_by_role': userRole,
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('Loan created in Firestore: ${loanRef.id}');
      return loanRef.id;
    } catch (e) {
      print('Error creating loan: $e');
      return null;
    }
  }

  /// Update loan in Firestore
  Future<bool> updateLoan(
    String firestoreLoanId,
    Map<String, dynamic> updates,
    String userId,
    String userRole,
  ) async {
    try {
      await _firestore.collection('loans').doc(firestoreLoanId).update({
        ...updates,
        'updated_by': userId,
        'updated_by_role': userRole,
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('Loan updated in Firestore');
      return true;
    } catch (e) {
      print('Error updating loan: $e');
      return false;
    }
  }

  /// Get loans by role
  Query getLoansQuery(String userId, String userRole) {
    final loansRef = _firestore.collection('loans');

    switch (userRole) {
      case 'officer':
        // Officers see loans they created or are assigned to
        return loansRef.where('officer_id', isEqualTo: int.parse(userId));
      case 'reviewer':
      case 'admin':
        // Reviewers and admins see all loans
        return loansRef.orderBy('created_at', descending: true);
      default:
        // Beneficiaries see their own loans
        return loansRef.where('beneficiary_id', isEqualTo: int.parse(userId));
    }
  }

  /// Listen to loans
  Stream<QuerySnapshot> listenToLoans(String userId, String userRole) {
    return getLoansQuery(userId, userRole).snapshots();
  }

  // ==================== MEDIA SUBMISSIONS ====================

  /// Upload media file to Firebase Storage
  Future<String?> uploadMediaFile(
    File file,
    String submissionId,
    String mediaType,
  ) async {
    try {
      final fileExtension = file.path.split('.').last;
      final fileName = '$submissionId.$fileExtension';
      final folderPath = mediaType == 'image' ? 'images' : 'videos';
      final storageRef = _storage.ref().child('$folderPath/$fileName');

      // Upload file with metadata
      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: mediaType == 'image' ? 'image/jpeg' : 'video/mp4',
          customMetadata: {
            'submission_id': submissionId,
            'uploaded_at': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('Media file uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading media file: $e');
      return null;
    }
  }

  /// Create media submission in Firestore
  Future<String?> createMediaSubmission(
    MediaSubmissionModel submission,
    String userId,
    String userRole,
  ) async {
    try {
      final submissionRef = _firestore.collection('media_submissions').doc();

      await submissionRef.set({
        'submission_id': submission.submissionId,
        'loan_id': submission.loanId,
        'beneficiary_id': submission.beneficiaryId,
        'media_type': submission.mediaType,
        'file_url': submission.serverUrl,
        'file_size': submission.fileSize,
        'thumbnail_url': submission.thumbnailPath,
        'latitude': submission.latitude,
        'longitude': submission.longitude,
        'location_accuracy': submission.locationAccuracy,
        'address': submission.address,
        'captured_at':
            Timestamp.fromMillisecondsSinceEpoch(submission.capturedAt),
        'description': submission.description,
        'asset_category': submission.assetCategory,
        'status': submission.status,
        'ai_validation_score': submission.aiValidationScore,
        'ai_validation_result': submission.aiValidationResult,
        'created_by': userId,
        'created_by_role': userRole,
        'created_at': FieldValue.serverTimestamp(),
        'updated_by': userId,
        'updated_by_role': userRole,
        'updated_at': FieldValue.serverTimestamp(),
        'review_history': [],
      });

      print('Media submission created in Firestore: ${submissionRef.id}');
      return submissionRef.id;
    } catch (e) {
      print('Error creating media submission: $e');
      return null;
    }
  }

  /// Update media submission status
  Future<bool> updateSubmissionStatus(
    String firestoreSubmissionId,
    String status,
    String remarks,
    String userId,
    String userRole,
  ) async {
    try {
      final submissionRef =
          _firestore.collection('media_submissions').doc(firestoreSubmissionId);

      // Get current document to preserve review history
      final doc = await submissionRef.get();
      final reviewHistory = List<Map<String, dynamic>>.from(
        doc.data()?['review_history'] ?? [],
      );

      // Add new review to history
      reviewHistory.add({
        'status': status,
        'remarks': remarks,
        'reviewed_by': userId,
        'reviewed_by_role': userRole,
        'reviewed_at': FieldValue.serverTimestamp(),
      });

      await submissionRef.update({
        'status': status,
        'officer_remarks': remarks,
        'reviewed_by': userId,
        'reviewed_by_role': userRole,
        'reviewed_at': FieldValue.serverTimestamp(),
        'updated_by': userId,
        'updated_by_role': userRole,
        'updated_at': FieldValue.serverTimestamp(),
        'review_history': reviewHistory,
      });

      print('Submission status updated in Firestore');
      return true;
    } catch (e) {
      print('Error updating submission status: $e');
      return false;
    }
  }

  /// Get media submissions by role
  Query getMediaSubmissionsQuery(String userId, String userRole) {
    final submissionsRef = _firestore.collection('media_submissions');

    switch (userRole) {
      case 'officer':
        // Officers see submissions they created
        return submissionsRef
            .where('created_by', isEqualTo: userId)
            .orderBy('created_at', descending: true);
      case 'reviewer':
      case 'admin':
        // Reviewers and admins see all submissions
        return submissionsRef.orderBy('created_at', descending: true);
      default:
        // Beneficiaries see their own submissions
        return submissionsRef
            .where('beneficiary_id', isEqualTo: int.parse(userId))
            .orderBy('created_at', descending: true);
    }
  }

  /// Listen to media submissions
  Stream<QuerySnapshot> listenToMediaSubmissions(
      String userId, String userRole) {
    return getMediaSubmissionsQuery(userId, userRole).snapshots();
  }

  /// Get submissions by status
  Stream<QuerySnapshot> listenToSubmissionsByStatus(
    String status,
    String userId,
    String userRole,
  ) {
    Query query = _firestore.collection('media_submissions');

    // Apply role-based filtering
    if (userRole == 'officer') {
      query = query.where('created_by', isEqualTo: userId);
    } else if (userRole != 'admin' && userRole != 'reviewer') {
      query = query.where('beneficiary_id', isEqualTo: int.parse(userId));
    }

    // Apply status filter
    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.orderBy('created_at', descending: true).snapshots();
  }

  // ==================== SYNC LOGGING ====================

  /// Log sync operation
  Future<void> logSyncOperation({
    required String entityType,
    required String operation,
    required String userId,
    required String userRole,
    required bool success,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('sync_logs').add({
        'entity_type': entityType,
        'operation': operation,
        'user_id': userId,
        'user_role': userRole,
        'success': success,
        'error_message': errorMessage,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging sync operation: $e');
    }
  }

  /// Get sync logs for user
  Stream<QuerySnapshot> getSyncLogs(String userId, {int limit = 50}) {
    return _firestore
        .collection('sync_logs')
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  // ==================== CONFLICT RESOLUTION ====================

  /// Detect and resolve conflicts
  Future<ConflictResolution> detectConflict({
    required Map<String, dynamic> localData,
    required DocumentSnapshot remoteDoc,
    required String userRole,
  }) async {
    if (!remoteDoc.exists) {
      return ConflictResolution(
        action: ConflictAction.useLocal,
        reason: 'Remote document does not exist',
      );
    }

    final remoteData = remoteDoc.data() as Map<String, dynamic>;

    // Get timestamps
    final localUpdatedAt = localData['updated_at'] as int?;
    final remoteUpdatedAt =
        (remoteData['updated_at'] as Timestamp?)?.millisecondsSinceEpoch;

    if (localUpdatedAt == null || remoteUpdatedAt == null) {
      return ConflictResolution(
        action: ConflictAction.useLocal,
        reason: 'Missing timestamp data',
      );
    }

    // Get authority levels
    final localRole = localData['updated_by_role'] as String? ?? userRole;
    final remoteRole = remoteData['updated_by_role'] as String? ?? 'unknown';

    final localAuthority = _getAuthorityLevel(localRole);
    final remoteAuthority = _getAuthorityLevel(remoteRole);

    // Authority-based resolution
    if (remoteAuthority > localAuthority) {
      return ConflictResolution(
        action: ConflictAction.useRemote,
        reason: 'Remote has higher authority ($remoteRole > $localRole)',
        mergedData: remoteData,
      );
    } else if (localAuthority > remoteAuthority) {
      return ConflictResolution(
        action: ConflictAction.useLocal,
        reason: 'Local has higher authority ($localRole > $remoteRole)',
      );
    } else {
      // Same authority - use timestamp (last write wins)
      if (remoteUpdatedAt > localUpdatedAt) {
        return ConflictResolution(
          action: ConflictAction.useRemote,
          reason: 'Remote is more recent',
          mergedData: remoteData,
        );
      } else {
        return ConflictResolution(
          action: ConflictAction.useLocal,
          reason: 'Local is more recent',
        );
      }
    }
  }

  int _getAuthorityLevel(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 3;
      case 'reviewer':
        return 2;
      case 'officer':
        return 1;
      default:
        return 0;
    }
  }

  // ==================== BATCH OPERATIONS ====================

  /// Batch write operations
  Future<bool> batchWrite(List<BatchOperation> operations) async {
    try {
      final batch = _firestore.batch();

      for (final op in operations) {
        final docRef = _firestore.collection(op.collection).doc(op.documentId);

        switch (op.type) {
          case BatchOperationType.set:
            batch.set(docRef, op.data, SetOptions(merge: op.merge));
            break;
          case BatchOperationType.update:
            batch.update(docRef, op.data);
            break;
          case BatchOperationType.delete:
            batch.delete(docRef);
            break;
        }
      }

      await batch.commit();
      print('Batch write completed: ${operations.length} operations');
      return true;
    } catch (e) {
      print('Error in batch write: $e');
      return false;
    }
  }

  // ==================== UTILITY METHODS ====================

  /// Check Firestore connection
  Future<bool> checkConnection() async {
    try {
      await _firestore.collection('_health_check').doc('ping').get();
      return true;
    } catch (e) {
      print('Firestore connection check failed: $e');
      return false;
    }
  }

  /// Enable/disable network
  Future<void> enableNetwork() async {
    try {
      await _firestore.enableNetwork();
      print('Firebase network enabled');
    } catch (e) {
      print('Error enabling network: $e');
    }
  }

  Future<void> disableNetwork() async {
    try {
      await _firestore.disableNetwork();
      print('Firebase network disabled');
    } catch (e) {
      print('Error disabling network: $e');
    }
  }

  /// Clear offline cache
  Future<void> clearCache() async {
    try {
      await _firestore.clearPersistence();
      print('Firebase cache cleared');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Get pending write count
  Future<int> getPendingWriteCount() async {
    // Note: This is an estimation based on cache
    // Firebase SDK doesn't expose exact pending write count
    return 0;
  }
}

// ==================== HELPER CLASSES ====================

class ConflictResolution {
  final ConflictAction action;
  final String reason;
  final Map<String, dynamic>? mergedData;

  ConflictResolution({
    required this.action,
    required this.reason,
    this.mergedData,
  });
}

enum ConflictAction {
  useLocal,
  useRemote,
  merge,
  manualResolve,
}

class BatchOperation {
  final String collection;
  final String? documentId;
  final Map<String, dynamic> data;
  final BatchOperationType type;
  final bool merge;

  BatchOperation({
    required this.collection,
    this.documentId,
    required this.data,
    required this.type,
    this.merge = false,
  });
}

enum BatchOperationType {
  set,
  update,
  delete,
}
