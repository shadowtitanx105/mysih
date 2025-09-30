import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/constants.dart';
import '../../auth/screens/login_screen.dart';

class AuthorityHomeScreen extends StatefulWidget {
  const AuthorityHomeScreen({super.key});

  @override
  State<AuthorityHomeScreen> createState() => _AuthorityHomeScreenState();
}

class _AuthorityHomeScreenState extends State<AuthorityHomeScreen> {
  String _authorityName = '';
  String _authorityEmail = '';
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // all, pending, approved, rejected

  @override
  void initState() {
    super.initState();
    _loadAuthorityData();
  }

  Future<void> _loadAuthorityData() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authorityName = prefs.getString('authority_name') ?? '';
      _authorityEmail = prefs.getString('authority_email') ?? '';
    });
    
    await _loadReports();
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadReports() async {
    final prefs = await SharedPreferences.getInstance();
    final reportCount = prefs.getInt('authority_report_count') ?? 0;
    
    List<Map<String, dynamic>> loadedReports = [];
    for (int i = 0; i < reportCount; i++) {
      final reportData = {
        'index': i,
        'id': prefs.getInt('authority_report_${i}_id') ?? i,
        'itemName': prefs.getString('authority_report_${i}_itemName') ?? '',
        'description': prefs.getString('authority_report_${i}_description') ?? '',
        'trustScore': prefs.getDouble('authority_report_${i}_trustScore') ?? 0.0,
        'status': prefs.getString('authority_report_${i}_status') ?? 'pending',
        'timestamp': prefs.getInt('authority_report_${i}_timestamp') ?? DateTime.now().millisecondsSinceEpoch,
        'imagePath': prefs.getString('authority_report_${i}_imagePath') ?? '',
        'latitude': prefs.getDouble('authority_report_${i}_latitude') ?? 0.0,
        'longitude': prefs.getDouble('authority_report_${i}_longitude') ?? 0.0,
        'userName': prefs.getString('authority_report_${i}_userName') ?? 'Unknown',
        'userPhone': prefs.getString('authority_report_${i}_userPhone') ?? '',
      };
      loadedReports.add(reportData);
    }
    
    // Sort by timestamp (newest first)
    loadedReports.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
    
    setState(() {
      _reports = loadedReports;
    });
  }

  List<Map<String, dynamic>> get _filteredReports {
    if (_filterStatus == 'all') return _reports;
    return _reports.where((report) => report['status'] == _filterStatus).toList();
  }

  int get _pendingCount {
    return _reports.where((r) => r['status'] == 'pending').length;
  }

  int get _approvedCount {
    return _reports.where((r) => r['status'] == 'approved').length;
  }

  int get _rejectedCount {
    return _reports.where((r) => r['status'] == 'rejected').length;
  }

  Future<void> _updateReportStatus(Map<String, dynamic> report, String newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${newStatus == 'approved' ? 'Approve' : 'Reject'} Report'),
        content: Text(
          'Are you sure you want to ${newStatus == 'approved' ? 'approve' : 'reject'} this report for ${report['itemName']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: newStatus == 'approved' 
                  ? AppColors.successColor 
                  : AppColors.errorColor,
            ),
            child: Text(newStatus == 'approved' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final reportIndex = report['index'] as int;
      final reportId = report['id'] as int;
      
      // Update in authority queue
      await prefs.setString('authority_report_${reportIndex}_status', newStatus);
      
      // Update in user's reports
      final userReportCount = prefs.getInt('report_count') ?? 0;
      for (int i = 0; i < userReportCount; i++) {
        final userId = prefs.getInt('report_${i}_id');
        if (userId == reportId) {
          await prefs.setString('report_${i}_status', newStatus);
          break;
        }
      }
      
      await _loadReports();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report ${newStatus == 'approved' ? 'approved' : 'rejected'} successfully'),
            backgroundColor: newStatus == 'approved' 
                ? AppColors.successColor 
                : AppColors.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update report: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  void _showReportDetails(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  report['itemName'] as String,
                  style: AppTextStyles.heading1,
                ),
                
                const SizedBox(height: 8),
                
                // User info
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${report['userName']} • ${report['userPhone']}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Image
                if (report['imagePath'] != null && (report['imagePath'] as String).isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(report['imagePath'] as String),
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Trust Score
                _buildDetailCard(
                  'AI Trust Score',
                  Icons.psychology,
                  AppColors.primaryColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Trust Score',
                            style: AppTextStyles.bodyMedium,
                          ),
                          Text(
                            '${((report['trustScore'] as double) * 100).toStringAsFixed(0)}%',
                            style: AppTextStyles.heading2.copyWith(
                              color: _getTrustScoreColor(report['trustScore'] as double),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTrustScoreBar(report['trustScore'] as double),
                      const SizedBox(height: 8),
                      Text(
                        _getTrustScoreDescription(report['trustScore'] as double),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Location
                _buildDetailCard(
                  'Location',
                  Icons.location_on,
                  AppColors.successColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Latitude: ${(report['latitude'] as double).toStringAsFixed(6)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        'Longitude: ${(report['longitude'] as double).toStringAsFixed(6)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Description
                _buildDetailCard(
                  'Description',
                  Icons.description,
                  AppColors.infoColor,
                  child: Text(
                    report['description'] as String,
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Timestamp
                _buildDetailCard(
                  'Submitted',
                  Icons.access_time,
                  Colors.grey,
                  child: Text(
                    _formatFullTimestamp(report['timestamp'] as int),
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Action buttons (only for pending reports)
                if (report['status'] == 'pending') ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateReportStatus(report, 'rejected');
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.errorColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateReportStatus(report, 'approved');
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: report['status'] == 'approved' 
                          ? AppColors.successColor.withOpacity(0.1)
                          : AppColors.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          report['status'] == 'approved' 
                              ? Icons.check_circle 
                              : Icons.cancel,
                          color: report['status'] == 'approved' 
                              ? AppColors.successColor 
                              : AppColors.errorColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Report ${report['status'] == 'approved' ? 'Approved' : 'Rejected'}',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: report['status'] == 'approved' 
                                ? AppColors.successColor 
                                : AppColors.errorColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailCard(String title, IconData icon, Color color, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTrustScoreBar(double score) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: score,
        child: Container(
          decoration: BoxDecoration(
            color: _getTrustScoreColor(score),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.person),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _authorityName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _authorityEmail,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.errorColor),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: AppColors.errorColor)),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsCards(),
                _buildFilterChips(),
                Expanded(child: _buildReportsList()),
              ],
            ),
    );
  }

  Widget _buildStatsCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Pending',
              _pendingCount.toString(),
              Icons.pending,
              AppColors.warningColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Approved',
              _approvedCount.toString(),
              Icons.check_circle,
              AppColors.successColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Rejected',
              _rejectedCount.toString(),
              Icons.cancel,
              AppColors.errorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.heading1.copyWith(
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('Pending', 'pending'),
            const SizedBox(width: 8),
            _buildFilterChip('Approved', 'approved'),
            const SizedBox(width: 8),
            _buildFilterChip('Rejected', 'rejected'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      selectedColor: AppColors.primaryColor.withOpacity(0.2),
      checkmarkColor: AppColors.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryColor : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildReportsList() {
    final filteredReports = _filteredReports;
    
    if (filteredReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_filterStatus == 'all' ? '' : _filterStatus} reports',
              style: AppTextStyles.heading2.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredReports.length,
        itemBuilder: (context, index) {
          final report = filteredReports[index];
          return _buildReportCard(report);
        },
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final status = report['status'] as String;
    final trustScore = report['trustScore'] as double;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (status) {
      case 'approved':
        statusColor = AppColors.successColor;
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case 'rejected':
        statusColor = AppColors.errorColor;
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      default:
        statusColor = AppColors.warningColor;
        statusIcon = Icons.pending;
        statusText = 'Pending';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showReportDetails(report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report['itemName'] as String,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              report['userName'] as String,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
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
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Trust Score indicator
              Row(
                children: [
                  Icon(
                    Icons.shield,
                    size: 18,
                    color: _getTrustScoreColor(trustScore),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Trust Score',
                              style: AppTextStyles.bodySmall,
                            ),
                            Text(
                              '${(trustScore * 100).toStringAsFixed(0)}%',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getTrustScoreColor(trustScore),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: trustScore,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _getTrustScoreColor(trustScore),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTimestamp(report['timestamp'] as int),
                    style: AppTextStyles.caption,
                  ),
                  if (status == 'pending')
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.cancel, size: 20),
                          onPressed: () => _updateReportStatus(report, 'rejected'),
                          color: AppColors.errorColor,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.check_circle, size: 20),
                          onPressed: () => _updateReportStatus(report, 'approved'),
                          color: AppColors.successColor,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTrustScoreColor(double score) {
    if (score >= 0.7) return AppColors.successColor;
    if (score >= 0.4) return AppColors.warningColor;
    return AppColors.errorColor;
  }

  String _getTrustScoreDescription(double score) {
    if (score >= 0.8) {
      return 'High confidence match. Very low likelihood of fraud.';
    } else if (score >= 0.6) {
      return 'Good match. Low likelihood of fraud.';
    } else if (score >= 0.4) {
      return 'Moderate match. Manual review recommended.';
    } else {
      return 'Low confidence match. High likelihood of fraud.';
    }
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatFullTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
