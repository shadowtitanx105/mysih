import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../../models/user_model.dart';
import '../utils/constants.dart';

class AuthProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  late final AuthService _authService;
  
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;

  AuthProvider(this._dbHelper) {
    _authService = AuthService(_dbHelper);
    _checkAuthStatus();
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  Future<void> _checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;
      
      if (isLoggedIn) {
        final userId = prefs.getInt(AppConstants.keyUserId);
        if (userId != null) {
          final users = await _dbHelper.query(
            'users',
            where: 'id = ?',
            whereArgs: [userId],
          );
          
          if (users.isNotEmpty) {
            _currentUser = UserModel.fromMap(users.first);
            _isAuthenticated = true;
          }
        }
      }
    } catch (e) {
      print('Error checking auth status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendOTP(String mobileNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.sendOTP(mobileNumber);
      
      if (!result.success) {
        _errorMessage = result.message;
      }
      
      return result.success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOTP(String mobileNumber, String otp) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.verifyOTP(mobileNumber, otp);
      
      if (result.success && result.user != null) {
        _currentUser = result.user;
        _isAuthenticated = true;
        
        // Save auth state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppConstants.keyIsLoggedIn, true);
        await prefs.setInt(AppConstants.keyUserId, result.user!.id!);
        await prefs.setString(AppConstants.keyUserRole, result.user!.role);
        
        return true;
      } else {
        _errorMessage = result.message;
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      
      // Clear auth state
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Clear database
      await _dbHelper.clearAllData();
      
      _currentUser = null;
      _isAuthenticated = false;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
