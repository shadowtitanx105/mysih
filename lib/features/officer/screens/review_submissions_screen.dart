import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/constants.dart';
import '../../../models/media_submission_model.dart';
import 'submission_detail_screen.dart';

class ReviewSubmissionsScreen extends StatefulWidget {
  const ReviewSubmissionsScreen({super.key});

  @override
  State<ReviewSubmissionsScreen> createState() => _ReviewSubmissionsScreenState();
}

class _ReviewSubmissionsScreenState extends State<ReviewSubmissionsScreen> {
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  String _selectedStatus = 'pending';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _statusFilters = [
    'pending',
    'under_review',
    'approved',
    'rejected',
    'all',
  ];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);

    try {
      final dbHelper = context.read<DatabaseHelper>();

      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (_selectedStatus != 'all') {
        whereClause = 'media_submissions.status = ?';
        whereArgs.add(_selectedStatus);
      }

      if (_startDate != null && _endDate != null) {
        final startTimestamp = _startDate!.millisecondsSinceEpoch ~/ 1000;
        final endTimestamp = _endDate!.millisecondsSinceEpoch ~/ 1000;

        if (whereClause.isNotEmpty) {
          whereClause += ' AND ';
        }
        whereClause += 'captured_at BETWEEN ? AND ?';
        whereArgs.addAll([startTimestamp, endTimestamp]);
      }

      // First, get count of raw media_submissions without joins
      final rawCountResult = await dbHelper.query(
        'media_submissions',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      );
      print('Raw media_submissions count: ${rawCountResult.length}');

      // Then, run your joined query
      final db = await dbHelper.database;
      final results = await db.rawQuery('''
      SELECT 
        media_submissions.*,
        users.full_name as beneficiary_name,
        users.mobile_number as beneficiary_mobile,
        loans.loan_id,
        loans.scheme_name,
        loans.loan_amount
      FROM media_submissions
      INNER JOIN beneficiaries ON media_submissions.beneficiary_id = beneficiaries.id
      INNER JOIN users ON beneficiaries.user_id = users.id
      INNER JOIN loans ON media_submissions.loan_id = loans.id
      ${whereClause.isNotEmpty ? 'WHERE $whereClause' : ''}
      ORDER BY media_submissions.captured_at DESC
    ''', whereArgs);
      print('Joined query results count: ${results.length}');
      print('Joined results: $results');

      setState(() {
        _submissions = results;
      });
    } catch (e) {
      print('Error loading submissions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading submissions: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadSubmissions();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadSubmissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Submissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          _buildFilterBar(),
          
          // Submissions List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadSubmissions,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildSubmissionsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusFilters.map((status) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_getStatusLabel(status)),
                          selected: _selectedStatus == status,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedStatus = status);
                              _loadSubmissions();
                            }
                          },
                          selectedColor: AppColors.primaryColor,
                          labelStyle: TextStyle(
                            color: _selectedStatus == status
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: _selectedStatus == status
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          if (_startDate != null && _endDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.date_range, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
                  style: AppTextStyles.bodySmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _clearDateFilter,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmissionsList() {
    if (_submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Submissions Found',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No submissions match your filters',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _submissions.length,
      itemBuilder: (context, index) {
        final submission = _submissions[index];
        return _buildSubmissionCard(submission);
      },
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission) {
    final capturedAt = DateTime.fromMillisecondsSinceEpoch(
      (submission['captured_at'] as int) * 1000,
    );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SubmissionDetailScreen(
                submissionId: submission['id'] as int,
              ),
            ),
          ).then((_) => _loadSubmissions());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: AppColors.backgroundColor,
                  child: submission['media_type'] == 'video'
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.videocam,
                              size: 40,
                              color: AppColors.textSecondary,
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Icon(
                          Icons.image,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            submission['beneficiary_name'] as String,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusBadge(submission['status'] as String),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Loan: ${submission['loan_id']}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      submission['scheme_name'] as String,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(capturedAt),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'approved':
        color = AppColors.statusApproved;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = AppColors.statusRejected;
        icon = Icons.cancel;
        break;
      case 'under_review':
        color = AppColors.warningColor;
        icon = Icons.visibility;
        break;
      default:
        color = AppColors.statusPending;
        icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            _getStatusLabel(status),
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Submissions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('Date Range'),
              subtitle: _startDate != null && _endDate != null
                  ? Text('${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}')
                  : const Text('No date filter'),
              onTap: () {
                Navigator.pop(context);
                _selectDateRange();
              },
            ),
          ],
        ),
        actions: [
          if (_startDate != null && _endDate != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _clearDateFilter();
              },
              child: const Text('Clear Filters'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'under_review':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'all':
        return 'All';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
