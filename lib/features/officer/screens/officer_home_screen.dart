import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/connectivity_provider.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/constants.dart';
import '../../../models/media_submission_model.dart';
import 'loan_entry_screen.dart';
import 'review_submissions_screen.dart';
import 'beneficiary_management_screen.dart';

class OfficerHomeScreen extends StatefulWidget {
  const OfficerHomeScreen({super.key});

  @override
  State<OfficerHomeScreen> createState() => _OfficerHomeScreenState();
}

class _OfficerHomeScreenState extends State<OfficerHomeScreen> {
  Map<String, int> _stats = {
    'total_loans': 1,
    'pending_submissions': 1,
    'approved_today': 0,
    'total_beneficiaries': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    //print("OfficerHomeScreen initState called");
    _maybeAddSampleReport();
    _loadDashboardStats();

  }

  Future<void> _maybeAddSampleReport() async {
    final authProvider = context.read<AuthProvider>();
    final dbHelper = context.read<DatabaseHelper>();

    print("Checking for sample report...");
    try{
      if (authProvider.currentUser?.role == 'authority') {
        final existing = await dbHelper.query(
          'media_submissions',
          where: 'submission_id = ?',
          whereArgs: ['sample_local_tractor'],
        );
        print("Existing sample: $existing");
        if (existing.isEmpty) {
          print("Inserting sample report...");
          await addLocalSampleReport();
        } else {
          print("Sample already exists, not inserting.");
        }
      }
    }
    catch(e, stack){
      print("Error in _maybeAddSampleReport: $e");
      print(stack);
    }
  }


  // Future<void> _maybeAddSampleReport() async {
  //   final authProvider = context.read<AuthProvider>();
  //   final dbHelper = context.read<DatabaseHelper>();
  //
  //   // Only for officer role
  //   if (authProvider.currentUser?.role == 'officer') {
  //     // Check if sample already exists
  //     final existing = await dbHelper.query(
  //       'media_submissions',
  //       where: 'submission_id = ?',
  //       whereArgs: ['sample_local_tractor'],
  //     );
  //     if (existing.isEmpty) {
  //       await addLocalSampleReport();
  //     }
  //   }
  // }


  Future<void> _loadDashboardStats() async {
    setState(() => _isLoading = true);

    try {
      final dbHelper = context.read<DatabaseHelper>();

      // Get total loans
      final loans = await dbHelper.query('loans');

      // Get pending submissions
      final pendingSubmissions = await dbHelper.query(
        'media_submissions',
        where: 'status = ?',
        whereArgs: ['pending'],
      );

      // Get approved submissions today
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 1000;
      final approvedToday = await dbHelper.query(
        'media_submissions',
        where: 'status = ? AND reviewed_at >= ?',
        whereArgs: ['approved', todayStart],
      );

      // Get total beneficiaries
      final beneficiaries = await dbHelper.query('beneficiaries');

      setState(() {
        _stats = {
          'total_loans': loans.length,
          'pending_submissions': pendingSubmissions.length,
          'approved_today': approvedToday.length,
          'total_beneficiaries': beneficiaries.length,
        };
      });
    } catch (e) {
      print('Error loading stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
// Add this method in _OfficerHomeScreenState

  Future<void> addLocalSampleReport() async {
    final dbHelper = context.read<DatabaseHelper>();

    // Use a unique submission ID
    final now = DateTime.now().millisecondsSinceEpoch;
    final sampleSubmission = MediaSubmissionModel(
      submissionId: 'sample_local_tractor',
      loanId: 1,
      beneficiaryId: 1,
      mediaType: 'image',
      serverUrl: 'assets/Tractor.jpg',
      filePath: 'assets/Tractor.jpg',
      fileSize: 0,
      thumbnailPath: 'assets/Tractor.jpg',
      latitude: 19.213135,
      longitude: 72.876678,
      locationAccuracy: 0.0,
      address: 'Sample Address',
      capturedAt: now,
      description: 'Tractor Report',
      assetCategory: 'Agriculture',
      status: 'pending',
      aiValidationScore: 98,
      aiValidationResult: 'tractor',
      createdAt: now,      // <-- Add this
      updatedAt: now,      // <-- Add this
    );



    // Insert into local DB
    await dbHelper.insert('media_submissions', sampleSubmission.toMap());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have a report!')),
      );
      _loadDashboardStats();
      print("Banana");
      // Refresh stats if needed
    }
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
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final connectivityProvider = context.watch<ConnectivityProvider>();
    final syncProvider = context.watch<SyncProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Dashboard'),
        actions: [
          // Sync Status
          IconButton(
            icon: Stack(
              children: [
                Icon(
                  connectivityProvider.isConnected
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                ),
                if (syncProvider.pendingCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.warningColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${syncProvider.pendingCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => syncProvider.syncNow(),
          ),

          // Profile Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.person),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authProvider.currentUser?.fullName ?? '',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      authProvider.currentUser?.mobileNumber ?? '',
                      style: AppTextStyles.bodySmall,
                    ),
                    Text(
                      'Officer',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryColor,
                      ),
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
                    Text('Logout',
                        style: TextStyle(color: AppColors.errorColor)),
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
      body: RefreshIndicator(
        onRefresh: _loadDashboardStats,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_stats.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: AppTextStyles.bodyLarge,
        ),
      );
    }
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          _buildWelcomeCard(),
          const SizedBox(height: 24),

          // Stats Grid
          Text(
            'Overview',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 16),
          _buildStatsGrid(),
          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 16),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final authProvider = context.read<AuthProvider>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryColor, AppColors.accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            authProvider.currentUser?.fullName ?? '',
            style: AppTextStyles.heading2.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                _getFormattedDate(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          'Total Loans',
          (_stats['total_loans'] ?? 0).toString(),
          Icons.account_balance_wallet,
          AppColors.primaryColor,
        ),
        _buildStatCard(
          'Pending Reviews',
          (_stats['pending_submissions'] ?? 0).toString(),
          Icons.pending_actions,
          AppColors.warningColor,
        ),
        _buildStatCard(
          'Approved Today',
          (_stats['approved_today'] ?? 0).toString(),
          Icons.check_circle,
          AppColors.successColor,
        ),
        _buildStatCard(
          'Beneficiaries',
          (_stats['total_beneficiaries'] ?? 0).toString(),
          Icons.people,
          AppColors.accentColor,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.heading1.copyWith(
              color: color,
              fontSize: 28,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        _buildActionCard(
          'Add New Loan',
          'Create a new loan entry for beneficiary',
          Icons.add_circle_outline,
          AppColors.primaryColor,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LoanEntryScreen(),
              ),
            ).then((_) => _loadDashboardStats());
          },
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          'Review Submissions',
          'View and approve pending media submissions',
          Icons.rate_review,
          AppColors.accentColor,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReviewSubmissionsScreen(),
              ),
            ).then((_) => _loadDashboardStats());
          },
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          'Manage Beneficiaries',
          'Add or update beneficiary information',
          Icons.people_outline,
          AppColors.successColor,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BeneficiaryManagementScreen(),
              ),
            ).then((_) => _loadDashboardStats());
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}
