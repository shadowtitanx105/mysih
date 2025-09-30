class BeneficiaryModel {
  final int? id;
  final int userId;
  final String beneficiaryCode;
  final String? address;
  final String? district;
  final String? state;
  final String? pincode;
  final String? aadhaarLastFour;
  final String? bankAccount;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;

  BeneficiaryModel({
    this.id,
    required this.userId,
    required this.beneficiaryCode,
    this.address,
    this.district,
    this.state,
    this.pincode,
    this.aadhaarLastFour,
    this.bankAccount,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'synced',
  });

  factory BeneficiaryModel.fromMap(Map<String, dynamic> map) {
    return BeneficiaryModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      beneficiaryCode: map['beneficiary_code'] as String,
      address: map['address'] as String?,
      district: map['district'] as String?,
      state: map['state'] as String?,
      pincode: map['pincode'] as String?,
      aadhaarLastFour: map['aadhaar_last_four'] as String?,
      bankAccount: map['bank_account'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'beneficiary_code': beneficiaryCode,
      'address': address,
      'district': district,
      'state': state,
      'pincode': pincode,
      'aadhaar_last_four': aadhaarLastFour,
      'bank_account': bankAccount,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'sync_status': syncStatus,
    };
  }

  BeneficiaryModel copyWith({
    int? id,
    int? userId,
    String? beneficiaryCode,
    String? address,
    String? district,
    String? state,
    String? pincode,
    String? aadhaarLastFour,
    String? bankAccount,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
  }) {
    return BeneficiaryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      beneficiaryCode: beneficiaryCode ?? this.beneficiaryCode,
      address: address ?? this.address,
      district: district ?? this.district,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      aadhaarLastFour: aadhaarLastFour ?? this.aadhaarLastFour,
      bankAccount: bankAccount ?? this.bankAccount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
