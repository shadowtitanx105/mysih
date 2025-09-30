class OfficerModel {
  final int? id;
  final int userId;
  final String officerCode;
  final String? designation;
  final String? department;
  final String? jurisdiction;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;

  OfficerModel({
    this.id,
    required this.userId,
    required this.officerCode,
    this.designation,
    this.department,
    this.jurisdiction,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'synced',
  });

  factory OfficerModel.fromMap(Map<String, dynamic> map) {
    return OfficerModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      officerCode: map['officer_code'] as String,
      designation: map['designation'] as String?,
      department: map['department'] as String?,
      jurisdiction: map['jurisdiction'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'officer_code': officerCode,
      'designation': designation,
      'department': department,
      'jurisdiction': jurisdiction,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'sync_status': syncStatus,
    };
  }

  OfficerModel copyWith({
    int? id,
    int? userId,
    String? officerCode,
    String? designation,
    String? department,
    String? jurisdiction,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
  }) {
    return OfficerModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      officerCode: officerCode ?? this.officerCode,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
