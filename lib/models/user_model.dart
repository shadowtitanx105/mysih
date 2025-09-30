class UserModel {
  final int? id;
  final String mobileNumber;
  final String role;
  final String fullName;
  final String? email;
  final int createdAt;
  final int updatedAt;
  final bool isVerified;
  final String syncStatus;

  UserModel({
    this.id,
    required this.mobileNumber,
    required this.role,
    required this.fullName,
    this.email,
    required this.createdAt,
    required this.updatedAt,
    this.isVerified = false,
    this.syncStatus = 'synced',
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      mobileNumber: map['mobile_number'] as String,
      role: map['role'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      isVerified: (map['is_verified'] as int) == 1,
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mobile_number': mobileNumber,
      'role': role,
      'full_name': fullName,
      'email': email,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_verified': isVerified ? 1 : 0,
      'sync_status': syncStatus,
    };
  }

  UserModel copyWith({
    int? id,
    String? mobileNumber,
    String? role,
    String? fullName,
    String? email,
    int? createdAt,
    int? updatedAt,
    bool? isVerified,
    String? syncStatus,
  }) {
    return UserModel(
      id: id ?? this.id,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVerified: isVerified ?? this.isVerified,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
