import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/constants.dart';
import '../../../models/loan_model.dart';

class LoanDetailsScreen extends StatelessWidget {
  final LoanModel loan;

  const LoanDetailsScreen({
    super.key,
    required this.loan,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Loan Status Card
            _buildStatusCard(),
            const SizedBox(height: 16),

            // Loan Information
            _buildInfoSection(
              'Loan Information',
              [
                _buildInfoRow('Loan ID', loan.loanId),
                _buildInfoRow('Scheme', loan.schemeName),
                _buildInfoRow('Amount', '₹${loan.loanAmount.toStringAsFixed(0)}'),
                _buildInfoRow('Purpose', loan.loanPurpose),
                _buildInfoRow('Status', _getStatusLabel(loan.status)),
                _buildInfoRow(
                  'Sanctioned Date',
                  _formatDate(DateTime.fromMillisecondsSinceEpoch(loan.sanctionedDate * 1000)),
                ),
                if (loan.disbursedDate != null)
                  _buildInfoRow(
                    'Disbursed Date',
                    _formatDate(DateTime.fromMillisecondsSinceEpoch(loan.disbursedDate! * 1000)),
                  ),
              ],
            ),

            if (loan.remarks != null && loan.remarks!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoSection(
                'Remarks',
                [
                  Text(
                    loan.remarks!,
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Upload Evidence Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Navigate to media upload screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Media upload feature coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Upload Evidence'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (loan.status) {
      case 'approved':
        statusColor = AppColors.statusApproved;
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case 'disbursed':
        statusColor = AppColors.successColor;
        statusIcon = Icons.account_balance_wallet;
        statusText = 'Disbursed';
        break;
      case 'rejected':
        statusColor = AppColors.statusRejected;
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      default:
        statusColor = AppColors.statusPending;
        statusIcon = Icons.pending;
        statusText = 'Pending';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(statusIcon, size: 64, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: AppTextStyles.heading2.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Loan Status',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
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
            Text(title, style: AppTextStyles.heading3),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'disbursed':
        return 'Disbursed';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      default:
        return 'Pending';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
