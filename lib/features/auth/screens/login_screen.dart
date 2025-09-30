import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/constants.dart';
import '../../user/screens/user_home_screen.dart';
import '../../authority/screens/authority_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;
  String _selectedRole = 'user';

  // Hardcoded demo credentials
  final Map<String, Map<String, dynamic>> _demoUsers = {
    '9876543210': {
      'name': 'Rahul Kumar',
      'otp': '123456',
      'id': 1,
      'loanItems': ['Tractor', 'Irrigation Pump', 'Seeds'], // Approved loan items
    },
    '9876543211': {
      'name': 'Priya Sharma',
      'otp': '123456',
      'id': 2,
      'loanItems': ['Dairy Equipment', 'Cattle Feed', 'Milking Machine'],
    },
  };

  final Map<String, Map<String, dynamic>> _demoAuthorities = {
    'officer@example.com': {
      'name': 'Officer Singh',
      'id': 101,
    },
    'admin@example.com': {
      'name': 'Admin Patel',
      'id': 102,
    },
  };

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    final phone = _phoneController.text.trim();
    
    if (_demoUsers.containsKey(phone)) {
      setState(() {
        _otpSent = true;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to $phone (Demo OTP: 123456)'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number not registered'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    
    final userData = _demoUsers[phone];
    
    if (userData != null && otp == userData['otp']) {
      // Save auth state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyIsLoggedIn, true);
      await prefs.setInt(AppConstants.keyUserId, userData['id']);
      await prefs.setString(AppConstants.keyUserRole, 'user');
      await prefs.setString('user_name', userData['name']);
      await prefs.setString('user_phone', phone);
      
      // Save approved loan items
      await prefs.setStringList('approved_loan_items', 
        List<String>.from(userData['loanItems']));
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UserHomeScreen()),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid OTP'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _loginAuthority() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    final email = _emailController.text.trim().toLowerCase();
    
    final authorityData = _demoAuthorities[email];
    
    if (authorityData != null) {
      // Save auth state
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyIsLoggedIn, true);
      await prefs.setInt(AppConstants.keyUserId, authorityData['id']);
      await prefs.setString(AppConstants.keyUserRole, 'authority');
      await prefs.setString('authority_name', authorityData['name']);
      await prefs.setString('authority_email', email);
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthorityHomeScreen()),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not authorized'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // App Icon/Logo
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Loan Verification',
                  style: AppTextStyles.heading1,
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'AI-Powered Digital System',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // Role Selection
                Text(
                  'Login As',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleCard(
                        role: 'user',
                        icon: Icons.person,
                        label: 'User',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildRoleCard(
                        role: 'authority',
                        icon: Icons.admin_panel_settings,
                        label: 'Authority',
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Dynamic Form based on role
                if (_selectedRole == 'user') ...[
                  _buildUserLoginForm(),
                ] else ...[
                  _buildAuthorityLoginForm(),
                ],
                
                const SizedBox(height: 32),
                
                // Demo Credentials Info
                _buildDemoCredentialsCard(),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Phone Number Input
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          enabled: !_otpSent,
          decoration: InputDecoration(
            labelText: 'Mobile Number',
            hintText: 'Enter 10-digit mobile number',
            prefixIcon: const Icon(Icons.phone_android),
            prefixText: '+91 ',
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
        
        if (_otpSent) ...[
          const SizedBox(height: 16),
          
          // OTP Input
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'OTP',
              hintText: 'Enter 6-digit OTP',
              prefixIcon: const Icon(Icons.lock_outline),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter OTP';
              }
              if (value.length != 6) {
                return 'Enter valid 6-digit OTP';
              }
              return null;
            },
          ),
        ],
        
        const SizedBox(height: 24),
        
        // Action Button
        ElevatedButton(
          onPressed: _isLoading 
              ? null 
              : (_otpSent ? _verifyOTP : _sendOTP),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _otpSent ? 'Verify OTP' : 'Send OTP',
                  style: AppTextStyles.buttonText,
                ),
        ),
        
        if (_otpSent) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _otpSent = false;
                _otpController.clear();
              });
            },
            child: const Text('Change Phone Number'),
          ),
        ],
      ],
    );
  }

  Widget _buildAuthorityLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email Input
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email Address',
            hintText: 'Enter your email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter email';
            }
            if (!value.contains('@')) {
              return 'Enter valid email';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 24),
        
        // Login Button
        ElevatedButton(
          onPressed: _isLoading ? null : _loginAuthority,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Login',
                  style: AppTextStyles.buttonText,
                ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedRole == role;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = role;
          _otpSent = false;
          _phoneController.clear();
          _emailController.clear();
          _otpController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryColor.withOpacity(0.1) 
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppColors.primaryColor 
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected 
                  ? AppColors.primaryColor 
                  : Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected 
                    ? AppColors.primaryColor 
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoCredentialsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.infoColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.infoColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Demo Credentials',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_selectedRole == 'user') ...[
            _buildCredentialInfo('User 1', '9876543210', 'OTP: 123456'),
            const SizedBox(height: 8),
            _buildCredentialInfo('User 2', '9876543211', 'OTP: 123456'),
          ] else ...[
            _buildCredentialInfo('Officer', 'officer@example.com', ''),
            const SizedBox(height: 8),
            _buildCredentialInfo('Admin', 'admin@example.com', ''),
          ],
        ],
      ),
    );
  }

  Widget _buildCredentialInfo(String role, String credential, String extra) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          role,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          credential,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontFamily: 'monospace',
          ),
        ),
        if (extra.isNotEmpty)
          Text(
            extra,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
      ],
    );
  }
}
