import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/constants.dart';
import '../../../models/loan_model.dart';
import '../../../models/beneficiary_model.dart';
import '../../../models/user_model.dart';

class LoanEntryScreen extends StatefulWidget {
  const LoanEntryScreen({super.key});

  @override
  State<LoanEntryScreen> createState() => _LoanEntryScreenState();
}

class _LoanEntryScreenState extends State<LoanEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _loanAmountController = TextEditingController();
  final _purposeController = TextEditingController();
  final _remarksController = TextEditingController();

  BeneficiaryModel? _selectedBeneficiary;
  UserModel? _selectedUser;
  String? _selectedScheme;
  DateTime _sanctionDate = DateTime.now();
  bool _isSearching = false;
  bool _isSaving = false;

  final List<String> _schemes = [
    'PMMY - Pradhan Mantri Mudra Yojana',
    'Stand-Up India',
    'MSME Loan',
    'Agriculture Loan',
    'Education Loan',
    'Housing Loan',
    'Vehicle Loan',
    'Business Expansion Loan',
    'Others',
  ];

  @override
  void dispose() {
    _mobileController.dispose();
    _loanAmountController.dispose();
    _purposeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _searchBeneficiary() async {
    if (_mobileController.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid 10-digit mobile number')),
      );
      return;
    }

    setState(() => _isSearching = true);

    try {
      final dbHelper = context.read<DatabaseHelper>();
      
      // Search for user with mobile number
      final users = await dbHelper.query(
        'users',
        where: 'mobile_number = ? AND role = ?',
        whereArgs: [_mobileController.text, 'beneficiary'],
      );

      if (users.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Beneficiary not found. Please register first.')),
          );
        }
        setState(() {
          _selectedBeneficiary = null;
          _selectedUser = null;
        });
        return;
      }

      final user = UserModel.fromMap(users.first);

      // Get beneficiary details
      final beneficiaries = await dbHelper.query(
        'beneficiaries',
        where: 'user_id = ?',
        whereArgs: [user.id],
      );

      if (beneficiaries.isNotEmpty) {
        setState(() {
          _selectedUser = user;
          _selectedBeneficiary = BeneficiaryModel.fromMap(beneficiaries.first);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Beneficiary found!'),
              backgroundColor: AppColors.successColor,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Beneficiary profile incomplete')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sanctionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _sanctionDate = picked);
    }
  }

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedBeneficiary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search and select a beneficiary')),
      );
      return;
    }

    if (_selectedScheme == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a loan scheme')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dbHelper = context.read<DatabaseHelper>();
      final authProvider = context.read<AuthProvider>();

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      final loan = LoanModel(
        loanId: 'LOAN-${const Uuid().v4().substring(0, 8).toUpperCase()}',
        beneficiaryId: _selectedBeneficiary!.id!,
        officerId: authProvider.currentUser!.id,
        loanAmount: double.parse(_loanAmountController.text),
        loanPurpose: _purposeController.text.trim(),
        schemeName: _selectedScheme!,
        sanctionedDate: _sanctionDate.millisecondsSinceEpoch ~/ 1000,
        status: 'approved',
        remarks: _remarksController.text.trim().isEmpty 
            ? null 
            : _remarksController.text.trim(),
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      );

      await dbHelper.insert('loans', loan.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan created successfully!'),
            backgroundColor: AppColors.successColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving loan: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Loan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Beneficiary Search Section
              Text(
                'Search Beneficiary',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mobileController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: 'Enter 10-digit mobile number',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter mobile number';
                        }
                        if (value.length != 10) {
                          return 'Enter valid 10-digit number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSearching ? null : _searchBeneficiary,
                    icon: _isSearching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                ],
              ),

              // Beneficiary Info Card
              if (_selectedBeneficiary != null && _selectedUser != null) ...[
                const SizedBox(height: 16),
                _buildBeneficiaryCard(),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Loan Details Section
              Text(
                'Loan Details',
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 16),

              // Scheme Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Loan Scheme *',
                  prefixIcon: Icon(Icons.account_balance),
                ),
                value: _selectedScheme,
                items: _schemes.map((scheme) {
                  return DropdownMenuItem(
                    value: scheme,
                    child: Text(
                      scheme,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedScheme = value);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a loan scheme';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Loan Amount
              TextFormField(
                controller: _loanAmountController,
                decoration: const InputDecoration(
                  labelText: 'Loan Amount *',
                  hintText: 'Enter amount in rupees',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter loan amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Enter valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Purpose
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(
                  labelText: 'Loan Purpose *',
                  hintText: 'e.g., Purchase of dairy equipment',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter loan purpose';
                  }
                  if (value.trim().length < 10) {
                    return 'Purpose must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Sanction Date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Sanction Date *',
                    prefixIcon: Icon(Icons.calendar_today),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    '${_sanctionDate.day}/${_sanctionDate.month}/${_sanctionDate.year}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Remarks (Optional)
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks (Optional)',
                  hintText: 'Any additional notes',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveLoan,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Create Loan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeneficiaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.successColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beneficiary Found',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.successColor,
                        ),
                      ),
                      Text(
                        'Details verified',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow('Name', _selectedUser!.fullName),
            _buildInfoRow('Mobile', _selectedUser!.mobileNumber),
            _buildInfoRow('Code', _selectedBeneficiary!.beneficiaryCode),
            if (_selectedBeneficiary!.district != null)
              _buildInfoRow('District', _selectedBeneficiary!.district!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
