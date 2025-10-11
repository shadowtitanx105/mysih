import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/constants.dart';
import '../../user/screens/user_home_screen.dart';
import '../../authority/screens/authority_home_screen.dart';
import '../../officer/screens/officer_home_screen.dart';

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
  bool _isHindi = false; // Language toggle state

  // Translation maps
  final Map<String, Map<String, String>> _translations = {
    'appTitle': {'en': 'Loan Saathi', 'hi': 'ऋण साथी'},
    'appSubtitle': {'en': 'AI-Powered Digital System', 'hi': 'एआई-संचालित डिजिटल प्रणाली'},
    'loginAs': {'en': 'Login As', 'hi': 'लॉगिन करें'},
    'user': {'en': 'User', 'hi': 'उपयोगकर्ता'},
    'authority': {'en': 'Authority', 'hi': 'अधिकारी'},
    'mobileNumber': {'en': 'Mobile Number', 'hi': 'मोबाइल नंबर'},
    'enterMobile': {'en': 'Enter 10-digit mobile number', 'hi': '10 अंकों का मोबाइल नंबर दर्ज करें'},
    'otp': {'en': 'OTP', 'hi': 'ओटीपी'},
    'enterOTP': {'en': 'Enter 6-digit OTP', 'hi': '6 अंकों का ओटीपी दर्ज करें'},
    'sendOTP': {'en': 'Send OTP', 'hi': 'ओटीपी भेजें'},
    'verifyOTP': {'en': 'Verify OTP', 'hi': 'ओटीपी सत्यापित करें'},
    'changePhone': {'en': 'Change Phone Number', 'hi': 'फ़ोन नंबर बदलें'},
    'emailAddress': {'en': 'Email Address', 'hi': 'ईमेल पता'},
    'enterEmail': {'en': 'Enter your email', 'hi': 'अपना ईमेल दर्ज करें'},
    'login': {'en': 'Login', 'hi': 'लॉगिन'},
    'demoCredentials': {'en': 'Demo Credentials', 'hi': 'डेमो क्रेडेंशियल'},
    'user1': {'en': 'User 1', 'hi': 'उपयोगकर्ता 1'},
    'user2': {'en': 'User 2', 'hi': 'उपयोगकर्ता 2'},
    'officer': {'en': 'Officer', 'hi': 'अधिकारी'},
    'admin': {'en': 'Admin', 'hi': 'व्यवस्थापक'},
    'pleaseEnterMobile': {'en': 'Please enter mobile number', 'hi': 'कृपया मोबाइल नंबर दर्ज करें'},
    'enterValid10': {'en': 'Enter valid 10-digit number', 'hi': 'मान्य 10 अंकों का नंबर दर्ज करें'},
    'pleaseEnterOTP': {'en': 'Please enter OTP', 'hi': 'कृपया ओटीपी दर्ज करें'},
    'enterValid6': {'en': 'Enter valid 6-digit OTP', 'hi': 'मान्य 6 अंकों का ओटीपी दर्ज करें'},
    'pleaseEnterEmail': {'en': 'Please enter email', 'hi': 'कृपया ईमेल दर्ज करें'},
    'enterValidEmail': {'en': 'Enter valid email', 'hi': 'मान्य ईमेल दर्ज करें'},
    'otpSentTo': {'en': 'OTP sent to', 'hi': 'ओटीपी भेजा गया'},
    'demoOTP': {'en': '(Demo OTP: 123456)', 'hi': '(डेमो ओटीपी: 123456)'},
    'phoneNotRegistered': {'en': 'Phone number not registered', 'hi': 'फ़ोन नंबर पंजीकृत नहीं है'},
    'invalidOTP': {'en': 'Invalid OTP', 'hi': 'अमान्य ओटीपी'},
    'emailNotAuthorized': {'en': 'Email not authorized', 'hi': 'ईमेल अधिकृत नहीं है'},
  };

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

  String _t(String key) {
    final lang = _isHindi ? 'hi' : 'en';
    return _translations[key]?[lang] ?? key;
  }

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
            content: Text('${_t('otpSentTo')} $phone ${_t('demoOTP')}'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('phoneNotRegistered')),
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
          SnackBar(
            content: Text(_t('invalidOTP')),
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
          MaterialPageRoute(builder: (context) => const OfficerHomeScreen()),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('emailNotAuthorized')),
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
                const SizedBox(height: 20),
                
                // Language Toggle Button
                Align(
                  alignment: Alignment.topRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isHindi = !_isHindi;
                      });
                    },
                    icon: Icon(
                      Icons.language,
                      size: 20,
                    ),
                    label: Text(
                      _isHindi ? 'English' : 'हिंदी',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
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
                  _t('appTitle'),
                  style: AppTextStyles.heading1,
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  _t('appSubtitle'),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // Role Selection
                Text(
                  _t('loginAs'),
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
                        label: _t('user'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildRoleCard(
                        role: 'authority',
                        icon: Icons.admin_panel_settings,
                        label: _t('authority'),
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/constants.dart';
import '../../user/screens/user_home_screen.dart';
import '../../authority/screens/authority_home_screen.dart';
import '../../officer/screens/officer_home_screen.dart';

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
  bool _isHindi = false; // Language toggle state

  // Translation maps
  final Map<String, Map<String, String>> _translations = {
    'appTitle': {'en': 'Loan Saathi', 'hi': 'ऋण साथी'},
    'appSubtitle': {'en': 'AI-Powered Digital System', 'hi': 'एआई-संचालित डिजिटल प्रणाली'},
    'loginAs': {'en': 'Login As', 'hi': 'लॉगिन करें'},
    'user': {'en': 'User', 'hi': 'उपयोगकर्ता'},
    'authority': {'en': 'Authority', 'hi': 'अधिकारी'},
    'mobileNumber': {'en': 'Mobile Number', 'hi': 'मोबाइल नंबर'},
    'enterMobile': {'en': 'Enter 10-digit mobile number', 'hi': '10 अंकों का मोबाइल नंबर दर्ज करें'},
    'otp': {'en': 'OTP', 'hi': 'ओटीपी'},
    'enterOTP': {'en': 'Enter 6-digit OTP', 'hi': '6 अंकों का ओटीपी दर्ज करें'},
    'sendOTP': {'en': 'Send OTP', 'hi': 'ओटीपी भेजें'},
    'verifyOTP': {'en': 'Verify OTP', 'hi': 'ओटीपी सत्यापित करें'},
    'changePhone': {'en': 'Change Phone Number', 'hi': 'फ़ोन नंबर बदलें'},
    'emailAddress': {'en': 'Email Address', 'hi': 'ईमेल पता'},
    'enterEmail': {'en': 'Enter your email', 'hi': 'अपना ईमेल दर्ज करें'},
    'login': {'en': 'Login', 'hi': 'लॉगिन'},
    'demoCredentials': {'en': 'Demo Credentials', 'hi': 'डेमो क्रेडेंशियल'},
    'user1': {'en': 'User 1', 'hi': 'उपयोगकर्ता 1'},
    'user2': {'en': 'User 2', 'hi': 'उपयोगकर्ता 2'},
    'officer': {'en': 'Officer', 'hi': 'अधिकारी'},
    'admin': {'en': 'Admin', 'hi': 'व्यवस्थापक'},
    'pleaseEnterMobile': {'en': 'Please enter mobile number', 'hi': 'कृपया मोबाइल नंबर दर्ज करें'},
    'enterValid10': {'en': 'Enter valid 10-digit number', 'hi': 'मान्य 10 अंकों का नंबर दर्ज करें'},
    'pleaseEnterOTP': {'en': 'Please enter OTP', 'hi': 'कृपया ओटीपी दर्ज करें'},
    'enterValid6': {'en': 'Enter valid 6-digit OTP', 'hi': 'मान्य 6 अंकों का ओटीपी दर्ज करें'},
    'pleaseEnterEmail': {'en': 'Please enter email', 'hi': 'कृपया ईमेल दर्ज करें'},
    'enterValidEmail': {'en': 'Enter valid email', 'hi': 'मान्य ईमेल दर्ज करें'},
    'otpSentTo': {'en': 'OTP sent to', 'hi': 'ओटीपी भेजा गया'},
    'demoOTP': {'en': '(Demo OTP: 123456)', 'hi': '(डेमो ओटीपी: 123456)'},
    'phoneNotRegistered': {'en': 'Phone number not registered', 'hi': 'फ़ोन नंबर पंजीकृत नहीं है'},
    'invalidOTP': {'en': 'Invalid OTP', 'hi': 'अमान्य ओटीपी'},
    'emailNotAuthorized': {'en': 'Email not authorized', 'hi': 'ईमेल अधिकृत नहीं है'},
  };

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

  String _t(String key) {
    final lang = _isHindi ? 'hi' : 'en';
    return _translations[key]?[lang] ?? key;
  }

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
            content: Text('${_t('otpSentTo')} $phone ${_t('demoOTP')}'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('phoneNotRegistered')),
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
          SnackBar(
            content: Text(_t('invalidOTP')),
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
          MaterialPageRoute(builder: (context) => const OfficerHomeScreen()),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('emailNotAuthorized')),
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
                const SizedBox(height: 20),
                
                // Language Toggle Button
                Align(
                  alignment: Alignment.topRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isHindi = !_isHindi;
                      });
                    },
                    icon: Icon(
                      Icons.language,
                      size: 20,
                    ),
                    label: Text(
                      _isHindi ? 'English' : 'हिंदी',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
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
                  _t('appTitle'),
                  style: AppTextStyles.heading1,
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  _t('appSubtitle'),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // Role Selection
                Text(
                  _t('loginAs'),
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
                        label: _t('user'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildRoleCard(
                        role: 'authority',
                        icon: Icons.admin_panel_settings,
                        label: _t('authority'),
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
            labelText: _t('mobileNumber'),
            hintText: _t('enterMobile'),
            prefixIcon: const Icon(Icons.phone_android),
            prefixText: '+91 ',
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return _t('pleaseEnterMobile');
            }
            if (value.length != 10) {
              return _t('enterValid10');
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
              labelText: _t('otp'),
              hintText: _t('enterOTP'),
              prefixIcon: const Icon(Icons.lock_outline),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return _t('pleaseEnterOTP');
              }
              if (value.length != 6) {
                return _t('enterValid6');
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
                  _otpSent ? _t('verifyOTP') : _t('sendOTP'),
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
            child: Text(_t('changePhone')),
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
            labelText: _t('emailAddress'),
            hintText: _t('enterEmail'),
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return _t('pleaseEnterEmail');
            }
            if (!value.contains('@')) {
              return _t('enterValidEmail');
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
              : Text(
                  _t('login'),
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
                _t('demoCredentials'),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_selectedRole == 'user') ...[
            _buildCredentialInfo(_t('user1'), '9876543210', '${_t('otp')}: 123456'),
            const SizedBox(height: 8),
            _buildCredentialInfo(_t('user2'), '9876543211', '${_t('otp')}: 123456'),
          ] else ...[
            _buildCredentialInfo(_t('officer'), 'officer@example.com', ''),
            const SizedBox(height: 8),
            _buildCredentialInfo(_t('admin'), 'admin@example.com', ''),
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
            labelText: _t('mobileNumber'),
            hintText: _t('enterMobile'),
            prefixIcon: const Icon(Icons.phone_android),
            prefixText: '+91 ',
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return _t('pleaseEnterMobile');
            }
            if (value.length != 10) {
              return _t('enterValid10');
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
              labelText: _t('otp'),
              hintText: _t('enterOTP'),
              prefixIcon: const Icon(Icons.lock_outline),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return _t('pleaseEnterOTP');
              }
              if (value.length != 6) {
                return _t('enterValid6');
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
                  _otpSent ? _t('verifyOTP') : _t('sendOTP'),
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
            child: Text(_t('changePhone')),
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
            labelText: _t('emailAddress'),
            hintText: _t('enterEmail'),
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return _t('pleaseEnterEmail');
            }
            if (!value.contains('@')) {
              return _t('enterValidEmail');
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
              : Text(
                  _t('login'),
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
                _t('demoCredentials'),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_selectedRole == 'user') ...[
            _buildCredentialInfo(_t('user1'), '9876543210', '${_t('otp')}: 123456'),
            const SizedBox(height: 8),
            _buildCredentialInfo(_t('user2'), '9876543211', '${_t('otp')}: 123456'),
          ] else ...[
            _buildCredentialInfo(_t('officer'), 'officer@example.com', ''),
            const SizedBox(height: 8),
            _buildCredentialInfo(_t('admin'), 'admin@example.com', ''),
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

