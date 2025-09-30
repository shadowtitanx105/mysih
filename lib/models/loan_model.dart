class LoanModel {
  final int? id;
  final String loanId;
  final int beneficiaryId;
  final int? officerId;
  final double loanAmount;
  final String loanPurpose;
  final String schemeName;
  final int sanctionedDate;
  final int? disbursedDate;
  final String status;
  final String? remarks;
  final int createdAt;
  final int updatedAt;
  final String syncStatus;

  LoanModel({
    this.id,
    required this.loanId,
    required this.beneficiaryId,
    this.officerId,
    required this.loanAmount,
    required this.loanPurpose,
    required this.schemeName,
    required this.sanctionedDate,
    this.disbursedDate,
    this.status = 'pending',
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = 'synced',
  });

  factory LoanModel.fromMap(Map<String, dynamic> map) {
    return LoanModel(
      id: map['id'] as int?,
      loanId: map['loan_id'] as String,
      beneficiaryId: map['beneficiary_id'] as int,
      officerId: map['officer_id'] as int?,
      loanAmount: (map['loan_amount'] as num).toDouble(),
      loanPurpose: map['loan_purpose'] as String,
      schemeName: map['scheme_name'] as String,
      sanctionedDate: map['sanctioned_date'] as int,
      disbursedDate: map['disbursed_date'] as int?,
      status: map['status'] as String? ?? 'pending',
      remarks: map['remarks'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loan_id': loanId,
      'beneficiary_id': beneficiaryId,
      'officer_id': officerId,
      'loan_amount': loanAmount,
      'loan_purpose': loanPurpose,
      'scheme_name': schemeName,
      'sanctioned_date': sanctionedDate,
      'disbursed_date': disbursedDate,
      'status': status,
      'remarks': remarks,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'sync_status': syncStatus,
    };
  }

  LoanModel copyWith({
    int? id,
    String? loanId,
    int? beneficiaryId,
    int? officerId,
    double? loanAmount,
    String? loanPurpose,
    String? schemeName,
    int? sanctionedDate,
    int? disbursedDate,
    String? status,
    String? remarks,
    int? createdAt,
    int? updatedAt,
    String? syncStatus,
  }) {
    return LoanModel(
      id: id ?? this.id,
      loanId: loanId ?? this.loanId,
      beneficiaryId: beneficiaryId ?? this.beneficiaryId,
      officerId: officerId ?? this.officerId,
      loanAmount: loanAmount ?? this.loanAmount,
      loanPurpose: loanPurpose ?? this.loanPurpose,
      schemeName: schemeName ?? this.schemeName,
      sanctionedDate: sanctionedDate ?? this.sanctionedDate,
      disbursedDate: disbursedDate ?? this.disbursedDate,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
