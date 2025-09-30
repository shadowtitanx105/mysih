import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/constants.dart';
import '../../../models/media_submission_model.dart';

class SubmissionDetailScreen extends StatefulWidget {
  final int submissionId;

  const SubmissionDetailScreen({
    super.key,
    required this.submissionId,
  });

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  Map<String, dynamic>? _submissionData;
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  bool _isProcessing = false;
  final _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSubmissionDetails();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadSubmissionDetails() async {
    setState(() => _isLoading = true);

    try {
      final dbHelper = context.read<DatabaseHelper>();
      final db = await dbHelper.database;

      final results = await db.rawQuery('''
        SELECT 
          media_submissions.*,
          users.full_name as beneficiary_name,
          users.mobile_number as beneficiary_mobile,
          users.email as beneficiary_email,
          beneficiaries.beneficiary_code,
          beneficiaries.address,
          beneficiaries.district,
          beneficiaries.state,
          loans.loan_id,
          loans.scheme_name,
          loans.loan_amount,
          loans.loan_purpose,
          officer_users.full_name as reviewer_name
        FROM media_submissions
        INNER JOIN beneficiaries ON media_submissions.beneficiary_id = beneficiaries.id
        INNER JOIN users ON beneficiaries.user_id = users.id
        INNER JOIN loans ON media_submissions.loan_id = loans.id
        LEFT JOIN users as officer_users ON media_submissions.reviewed_by = officer_users.id
        WHERE media_submissions.id = ?
      ''', [widget.submissionId]);

      if (results.isNotEmpty) {
        setState(() {
          _submissionData = results.first;
        });

        // Initialize video player if media type is video
        if (_submissionData!['media_type'] == 'video') {
          final filePath = _submissionData!['file_path'] as String;
          if (await File(filePath).exists()) {
            _videoController = VideoPlayerController.file(File(filePath))
              ..initialize().then((_) {
                setState(() {});
              });
          }
        }
      }
    } catch (e) {
      print('Error loading submission details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSubmissionStatus(String newStatus) async {
    // Validate remarks for rejection
    if (newStatus == 'rejected' && _remarksController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remarks are required for rejection'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${newStatus == 'approved' ? 'Approve' : 'Reject'} Submission'),
        content: Text(
          'Are you sure you want to ${newStatus == 'approved' ? 'approve' : 'reject'} this submission?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'approved'
                  ? AppColors.successColor
                  : AppColors.errorColor,
            ),
            child: Text(newStatus == 'approved' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final dbHelper = context.read<DatabaseHelper>();
      final authProvider = context.read<AuthProvider>();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await dbHelper.update(
        'media_submissions',
        {
          'status': newStatus,
          'officer_remarks': _remarksController.text.trim(),
          'reviewed_by': authProvider.currentUser!.id,
          'reviewed_at': now,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [widget.submissionId],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Submission ${newStatus == 'approved' ? 'approved' : 'rejected'} successfully',
            ),
            backgroundColor: newStatus == 'approved'
                ? AppColors.successColor
                : AppColors.errorColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _submissionData == null
              ? const Center(child: Text('Submission not found'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final status = _submissionData!['status'] as String;
    final canReview = status == 'pending' || status == 'under_review';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media Display
          _buildMediaSection(),

          // Details Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge
                _buildStatusBadge(status),
                const SizedBox(height: 16),

                // Location & Time Info
                _buildLocationTimeCard(),
                const SizedBox(height: 16),

                // Beneficiary Info
                _buildInfoSection(
                  'Beneficiary Details',
                  [
                    _buildInfoRow('Name', _submissionData!['beneficiary_name']),
                    _buildInfoRow('Code', _submissionData!['beneficiary_code']),
                    _buildInfoRow('Mobile', _submissionData!['beneficiary_mobile']),
                    if (_submissionData!['beneficiary_email'] != null)
                      _buildInfoRow('Email', _submissionData!['beneficiary_email']),
                    if (_submissionData!['address'] != null)
                      _buildInfoRow('Address', _submissionData!['address']),
                    if (_submissionData!['district'] != null)
                      _buildInfoRow('District', _submissionData!['district']),
                  ],
                ),
                const SizedBox(height: 16),

                // Loan Info
                _buildInfoSection(
                  'Loan Details',
                  [
                    _buildInfoRow('Loan ID', _submissionData!['loan_id']),
                    _buildInfoRow('Scheme', _submissionData!['scheme_name']),
                    _buildInfoRow(
                      'Amount',
                      '₹${(_submissionData!['loan_amount'] as num).toStringAsFixed(0)}',
                    ),
                    _buildInfoRow('Purpose', _submissionData!['loan_purpose']),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                if (_submissionData!['description'] != null &&
                    (_submissionData!['description'] as String).isNotEmpty) ...[
                  Text('Description', style: AppTextStyles.heading3),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      _submissionData!['description'] as String,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // AI Validation (if available)
                if (_submissionData!['ai_validation_score'] != null) ...[
                  _buildAIValidationCard(),
                  const SizedBox(height: 16),
                ],

                // Previous Remarks (if reviewed)
                if (_submissionData!['officer_remarks'] != null &&
                    (_submissionData!['officer_remarks'] as String).isNotEmpty) ...[
                  Text('Officer Remarks', style: AppTextStyles.heading3),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _submissionData!['officer_remarks'] as String,
                          style: AppTextStyles.bodyMedium,
                        ),
                        if (_submissionData!['reviewer_name'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'By: ${_submissionData!['reviewer_name']}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Review Section (only if can review)
                if (canReview) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  Text('Review Submission', style: AppTextStyles.heading3),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _remarksController,
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      hintText: 'Enter your remarks (required for rejection)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () => _updateSubmissionStatus('rejected'),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.errorColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : () => _updateSubmissionStatus('approved'),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    final mediaType = _submissionData!['media_type'] as String;
    final filePath = _submissionData!['file_path'] as String;

    return Container(
      width: double.infinity,
      height: 300,
      color: Colors.black,
      child: mediaType == 'video'
          ? _buildVideoPlayer()
          : _buildImageViewer(filePath),
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
        IconButton(
          icon: Icon(
            _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
            size: 64,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _videoController!.value.isPlaying
                  ? _videoController!.pause()
                  : _videoController!.play();
            });
          },
        ),
      ],
    );
  }

  Widget _buildImageViewer(String filePath) {
    return File(filePath).existsSync()
        ? Image.file(
            File(filePath),
            fit: BoxFit.contain,
          )
        : const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 64, color: Colors.white54),
                SizedBox(height: 8),
                Text(
                  'Image not available',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'approved':
        color = AppColors.statusApproved;
        icon = Icons.check_circle;
        label = 'Approved';
        break;
      case 'rejected':
        color = AppColors.statusRejected;
        icon = Icons.cancel;
        label = 'Rejected';
        break;
      case 'under_review':
        color = AppColors.warningColor;
        icon = Icons.visibility;
        label = 'Under Review';
        break;
      default:
        color = AppColors.statusPending;
        icon = Icons.pending;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTimeCard() {
    final capturedAt = DateTime.fromMillisecondsSinceEpoch(
      (_submissionData!['captured_at'] as int) * 1000,
    );

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.errorColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_submissionData!['latitude'] != null &&
                          _submissionData!['longitude'] != null)
                        Text(
                          '${(_submissionData!['latitude'] as num).toStringAsFixed(6)}, ${(_submissionData!['longitude'] as num).toStringAsFixed(6)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          'Location not available',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Captured At',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _formatFullDateTime(capturedAt),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Card(
      elevation: 1,
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

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIValidationCard() {
    final score = (_submissionData!['ai_validation_score'] as num).toDouble();
    final result = _submissionData!['ai_validation_result'] as String?;

    Color scoreColor;
    if (score >= 80) {
      scoreColor = AppColors.successColor;
    } else if (score >= 60) {
      scoreColor = AppColors.warningColor;
    } else {
      scoreColor = AppColors.errorColor;
    }

    return Card(
      elevation: 1,
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
                const Icon(Icons.psychology, color: AppColors.accentColor),
                const SizedBox(width: 8),
                Text('AI Validation', style: AppTextStyles.heading3),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confidence Score',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${score.toStringAsFixed(1)}%',
                        style: AppTextStyles.heading2.copyWith(
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scoreColor),
                  ),
                  child: Text(
                    score >= 80 ? 'High' : score >= 60 ? 'Medium' : 'Low',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              Text(
                result,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatFullDateTime(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
  }
}
