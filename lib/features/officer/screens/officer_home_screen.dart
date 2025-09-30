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
    print("OfficerHomeScreen initState called");
    _testDatabase();

    _maybeAddTestData().then((_) {
      try {
        _maybeAddSampleReport();
        _loadDashboardStats();
      } catch (e) {
        print("Error during initial data load: $e");
      }
    });
  }



  Future<void> _maybeAddTestData() async {
    final dbHelper = context.read<DatabaseHelper>();
    final now = DateTime.now().millisecondsSinceEpoch;
    final authProvider = context.read<AuthProvider>();
    final officerId = authProvider.currentUser?.id ?? 1;
    final officerRole = authProvider.currentUser?.role ?? 'officer';

    Future<void> safeInsert(String table, Map<String, dynamic> data) async {
      try {
        final exists = await dbHelper.query(table,
            where: 'id = ?', whereArgs: [data['id']]);
        if (exists.isEmpty) {
          await dbHelper.insert(table, data);
          print('Inserted test data into $table');
        } else {
          print('$table test data exists, skipping insert');
        }
      } catch (e) {
        print('Error inserting test data into $table: $e');
      }
    }

    print('Starting test data insertion...');
    await safeInsert('users', {
      'id': 1,
      'mobile_number': '9999999999',
      'role': 'beneficiary',
      'full_name': 'Test Beneficiary',
      'created_at': now,
      'updated_at': now,
    });

    await safeInsert('beneficiaries', {
      'id': 1,
      'user_id': 1,
      'beneficiary_code': 'BEN123',
      'created_at': now,
      'updated_at': now,
    });

    // Fixed loan insertion with missing required fields
    await safeInsert('loans', {
      'id': 1,
      'loan_id': 'LN001',
      'beneficiary_id': 1,
      'officer_id': officerId,
      'loan_amount': 10000.0,
      'loan_purpose': 'Agriculture',
      'scheme_name': 'Sample Scheme',
      'sanctioned_date': now,
      'status': 'pending',
      'created_at': now,
      'updated_at': now,
      'created_by': officerId,  // Add this missing field
      'created_by_role': officerRole,  // Add this missing field too
    });

    print('Finished test data insertion');
  }





  Future<void> _testDatabase() async {
    try {
      final dbHelper = context.read<DatabaseHelper>();

      // Test basic database operation
      print("Testing database connection...");
      final testQuery = await dbHelper.query('sqlite_master', where: "type='table'");
      print("Available tables: $testQuery");

      // Test media_submissions table specifically
      final tableInfo = await dbHelper.query('sqlite_master',
          where: "type='table' AND name='media_submissions'");
      print("media_submissions table info: $tableInfo");

    } catch (e, stack) {
      print("Database test error: $e");
      print("Stack: $stack");
    }
  }

  Future<void> _maybeAddSampleReport() async {
    final authProvider = context.read<AuthProvider>();
    final dbHelper = context.read<DatabaseHelper>();

    print("=== SAMPLE REPORT DEBUG START ===");
    print("Current user: ${authProvider.currentUser}");
    print("Current user role: ${authProvider.currentUser?.role}");

    try {
      print("Checking for existing sample report...");
      final existing = await dbHelper.query(
        'media_submissions',
        where: 'submission_id = ?',
        whereArgs: ['sample_local_tractor'],
      );
      print("Existing sample query result: $existing");
      print("Existing sample count: ${existing.length}");

      if (existing.isEmpty) {
        print("No existing sample found. Inserting new sample...");
        await addLocalSampleReport();
        print("Sample insertion completed");
      } else {
        print("Sample already exists, not inserting.");
        print("Existing sample data: ${existing.first}");
      }

      // Verify the insertion by querying again
      print("Verifying sample exists after operation...");
      final verifyExisting = await dbHelper.query(
        'media_submissions',
        where: 'submission_id = ?',
        whereArgs: ['sample_local_tractor'],
      );
      print("Verification query result: $verifyExisting");
      print("Verification count: ${verifyExisting.length}");

      // Also check all media_submissions
      print("Checking all media_submissions...");
      final allSubmissions = await dbHelper.query('media_submissions');
      print("All submissions count: ${allSubmissions.length}");
      print("All submissions: $allSubmissions");

    } catch (e, stack) {
      print("Error in _maybeAddSampleReport: $e");
      print("Stack trace: $stack");
    }
    print("=== SAMPLE REPORT DEBUG END ===");
  }

  Future<void> addLocalSampleReport() async {
    print("=== ADD LOCAL SAMPLE REPORT START ===");

    try {
      final dbHelper = context.read<DatabaseHelper>();
      final now = DateTime.now().millisecondsSinceEpoch;
      final authProvider = context.read<AuthProvider>();
      final officerId = authProvider.currentUser?.id ?? 1;  // fallback dummy id
      final officerRole = authProvider.currentUser?.role ?? 'officer';  // fallback dummy role

      print("Creating MediaSubmissionModel...");
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
        createdAt: now,
        updatedAt: now,
          // Newly added fields:
          createdBy: officerId,
          createdByRole: officerRole
      );

      print("Sample submission object created");
      print("Sample submission data: ${sampleSubmission.toMap()}");

      // Insert into local DB
      print("Inserting into database...");
      final insertResult = await dbHelper.insert('media_submissions', sampleSubmission.toMap());
      print("Insert result: $insertResult");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample report created!')),
        );
        print("Refreshing dashboard stats...");
        await _loadDashboardStats();
        print("Dashboard stats refreshed");
      }
    } catch (e, stack) {
      print("Error in addLocalSampleReport: $e");
      print("Stack trace: $stack");
    }

    print("=== ADD LOCAL SAMPLE REPORT END ===");
  }

  Future<void> _loadDashboardStats() async {
    print("=== LOAD DASHBOARD STATS START ===");
    setState(() => _isLoading = true);

    try {
      final dbHelper = context.read<DatabaseHelper>();

      // Get total loans
      print("Querying loans...");
      final loans = await dbHelper.query('loans');
      print("Total loans found: ${loans.length}");

      // Get pending submissions
      print("Querying pending submissions...");
      final pendingSubmissions = await dbHelper.query(
        'media_submissions',
        where: 'status = ?',
        whereArgs: ['pending'],
      );
      print("Pending submissions found: ${pendingSubmissions.length}");
      print("Pending submissions data: $pendingSubmissions");

      // Get approved submissions today
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 1000;
      print("Querying approved submissions for today (timestamp >= $todayStart)...");
      final approvedToday = await dbHelper.query(
        'media_submissions',
        where: 'status = ? AND reviewed_at >= ?',
        whereArgs: ['approved', todayStart],
      );
      print("Approved today found: ${approvedToday.length}");

      // Get total beneficiaries
      print("Querying beneficiaries...");
      final beneficiaries = await dbHelper.query('beneficiaries');
      print("Total beneficiaries found: ${beneficiaries.length}");

      // Update stats
      final newStats = {
        'total_loans': loans.length,
        'pending_submissions': pendingSubmissions.length,
        'approved_today': approvedToday.length,
        'total_beneficiaries': beneficiaries.length,
      };

      print("New stats: $newStats");

      setState(() {
        _stats = newStats;
      });

      print("Stats updated in UI");

    } catch (e, stack) {
      print('Error loading stats: $e');
      print('Stack trace: $stack');
    } finally {
      setState(() => _isLoading = false);
      print("Loading state set to false");
    }

    print("=== LOAD DASHBOARD STATS END ===");
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