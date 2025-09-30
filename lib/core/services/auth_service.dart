import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/database_helper.dart';
import '../../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseHelper _dbHelper;
  
  String? _verificationId;
  
  AuthService(this._dbHelper);

  Future<AuthResult> sendOTP(String mobileNumber) async {
    try {
      // In development, we'll use a mock OTP for testing
      // In production, use Firebase Phone Auth
      
      // Generate and store OTP locally for testing
      final otp = _generateOTP();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await _dbHelper.insert('otp_verifications', {
        'mobile_number': mobileNumber,
        'otp_code': otp,
        'purpose': 'login',
        'is_verified': 0,
        'expires_at': now + (5 * 60 * 1000), // 5 minutes
        'created_at': now,
      });

      // For testing: Print OTP to console
      print('OTP for $mobileNumber: $otp');
      
      return AuthResult(
        success: true,
        message: 'OTP sent successfully',
        otp: otp, // Only for testing
      );

      // Production code (commented out):
      /*
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$mobileNumber',
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification
        },
        verificationFailed: (FirebaseAuthException e) {
          // Handle error
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
      */
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Failed to send OTP: ${e.toString()}',
      );
    }
  }

  Future<AuthResult> verifyOTP(String mobileNumber, String otp) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Get OTP from database
      final otpRecords = await _dbHelper.query(
        'otp_verifications',
        where: 'mobile_number = ? AND otp_code = ? AND is_verified = 0',
        whereArgs: [mobileNumber, otp],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (otpRecords.isEmpty) {
        return AuthResult(
          success: false,
          message: 'Invalid OTP',
        );
      }

      final otpRecord = otpRecords.first;
      final expiresAt = otpRecord['expires_at'] as int;

      if (now > expiresAt) {
        return AuthResult(
          success: false,
          message: 'OTP has expired',
        );
      }

      // Mark OTP as verified
      await _dbHelper.update(
        'otp_verifications',
        {'is_verified': 1},
        where: 'id = ?',
        whereArgs: [otpRecord['id']],
      );

      // Check if user exists
      final users = await _dbHelper.query(
        'users',
        where: 'mobile_number = ?',
        whereArgs: [mobileNumber],
      );

      UserModel? user;
      if (users.isEmpty) {
        // Create new user - default to beneficiary role
        // In production, role should be determined by backend
        final userId = await _dbHelper.insert('users', {
          'mobile_number': mobileNumber,
          'role': 'beneficiary',
          'full_name': 'User $mobileNumber',
          'created_at': now,
          'updated_at': now,
          'is_verified': 1,
          'sync_status': 'pending',
        });

        user = UserModel(
          id: userId,
          mobileNumber: mobileNumber,
          role: 'beneficiary',
          fullName: 'User $mobileNumber',
          createdAt: now,
          updatedAt: now,
          isVerified: true,
        );
      } else {
        user = UserModel.fromMap(users.first);
      }

      return AuthResult(
        success: true,
        message: 'Login successful',
        user: user,
      );
    } catch (e) {
      return AuthResult(
        success: false,
        message: 'Verification failed: ${e.toString()}',
      );
    }
  }

  Future<UserModel?> getCurrentUser() async {
    // In production, get from secure storage or token
    // For now, get the last verified user
    final users = await _dbHelper.query(
      'users',
      where: 'is_verified = 1',
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (users.isEmpty) return null;
    return UserModel.fromMap(users.first);
  }

  Future<void> logout() async {
    await _auth.signOut();
    // Clear user session
  }

  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }
}

class AuthResult {
  final bool success;
  final String message;
  final UserModel? user;
  final String? otp; // Only for testing

  AuthResult({
    required this.success,
    required this.message,
    this.user,
    this.otp,
  });
}
