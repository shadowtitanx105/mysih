class MediaSubmissionModel {
  final int? id;
  final String submissionId;
  final int loanId;
  final int beneficiaryId;
  final String mediaType;
  final String filePath;
  final int? fileSize;
  final String? thumbnailPath;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracy;
  final String? address;
  final int capturedAt;
  final String? description;
  final String? assetCategory;
  final String status;
  final double? aiValidationScore;
  final String? aiValidationResult;
  final String? officerRemarks;
  final int? reviewedBy;
  final int? reviewedAt;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;
  final String? serverUrl;

  MediaSubmissionModel({
    this.id,
    required this.submissionId,
    required this.loanId,
    required this.beneficiaryId,
    required this.mediaType,
    required this.filePath,
    this.fileSize,
    this.thumbnailPath,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    this.address,
    required this.capturedAt,
    this.description,
    this.assetCategory,
    this.status = 'pending',
    this.aiValidationScore,
    this.aiValidationResult,
    this.officerRemarks,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'pending',
    this.serverUrl,
  });

  factory MediaSubmissionModel.fromMap(Map<String, dynamic> map) {
    return MediaSubmissionModel(
      id: map['id'] as int?,
      submissionId: map['submission_id'] as String,
      loanId: map['loan_id'] as int,
      beneficiaryId: map['beneficiary_id'] as int,
      mediaType: map['media_type'] as String,
      filePath: map['file_path'] as String,
      fileSize: map['file_size'] as int?,
      thumbnailPath: map['thumbnail_path'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      locationAccuracy: map['location_accuracy'] as double?,
      address: map['address'] as String?,
      capturedAt: map['captured_at'] as int,
      description: map['description'] as String?,
      assetCategory: map['asset_category'] as String?,
      status: map['status'] as String? ?? 'pending',
      aiValidationScore: map['ai_validation_score'] as double?,
      aiValidationResult: map['ai_validation_result'] as String?,
      officerRemarks: map['officer_remarks'] as String?,
      reviewedBy: map['reviewed_by'] as int?,
      reviewedAt: map['reviewed_at'] as int?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      syncStatus: map['sync_status'] as String? ?? 'pending',
      serverUrl: map['server_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'submission_id': submissionId,
      'loan_id': loanId,
      'beneficiary_id': beneficiaryId,
      'media_type': mediaType,
      'file_path': filePath,
      'file_size': fileSize,
      'thumbnail_path': thumbnailPath,
      'latitude': latitude,
      'longitude': longitude,
      'location_accuracy': locationAccuracy,
      'address': address,
      'captured_at': capturedAt,
      'description': description,
      'asset_category': assetCategory,
      'status': status,
      'ai_validation_score': aiValidationScore,
      'ai_validation_result': aiValidationResult,
      'officer_remarks': officerRemarks,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'sync_status': syncStatus,
      'server_url': serverUrl,
    };
  }

  MediaSubmissionModel copyWith({
    int? id,
    String? submissionId,
    int? loanId,
    int? beneficiaryId,
    String? mediaType,
    String? filePath,
    int? fileSize,
    String? thumbnailPath,
    double? latitude,
    double? longitude,
    double? locationAccuracy,
    String? address,
    int? capturedAt,
    String? description,
    String? assetCategory,
    String? status,
    double? aiValidationScore,
    String? aiValidationResult,
    String? officerRemarks,
    int? reviewedBy,
    int? reviewedAt,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
    String? serverUrl,
  }) {
    return MediaSubmissionModel(
      id: id ?? this.id,
      submissionId: submissionId ?? this.submissionId,
      loanId: loanId ?? this.loanId,
      beneficiaryId: beneficiaryId ?? this.beneficiaryId,
      mediaType: mediaType ?? this.mediaType,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      address: address ?? this.address,
      capturedAt: capturedAt ?? this.capturedAt,
      description: description ?? this.description,
      assetCategory: assetCategory ?? this.assetCategory,
      status: status ?? this.status,
      aiValidationScore: aiValidationScore ?? this.aiValidationScore,
      aiValidationResult: aiValidationResult ?? this.aiValidationResult,
      officerRemarks: officerRemarks ?? this.officerRemarks,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }
}
