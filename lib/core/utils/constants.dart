import 'package:flutter/material.dart';

// App Constants
class AppConstants {
  static const String appName = 'Loan Utilization App';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String baseUrl = 'https://api.loanutilization.gov.in/v1';
  static const String apiKey = 'your_api_key_here';
  
  // Database
  static const String databaseName = 'loan_utilization.db';
  static const int databaseVersion = 2; // Updated for role-based tracking
  
  // Shared Preferences Keys
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyAuthToken = 'auth_token';
  static const String keyIsLoggedIn = 'is_logged_in';
  
  // OTP Configuration
  static const int otpLength = 6;
  static const int otpExpiryMinutes = 5;
  static const int otpResendSeconds = 60;
  
  // Media Configuration
  static const int maxImageSizeMB = 5;
  static const int maxVideoSizeMB = 50;
  static const int maxVideoDurationSeconds = 30;
  static const int imageQuality = 85;
  
  // Sync Configuration
  static const int syncIntervalMinutes = 15;
  static const int maxRetryAttempts = 3;
  static const int syncBatchSize = 10;
  
  // Location Configuration
  static const double locationAccuracyMeters = 50.0;
  static const int locationTimeoutSeconds = 30;
}

// Color Palette
class AppColors {
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color accentColor = Color(0xFFFF9800);
  
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFFA726);
  static const Color infoColor = Color(0xFF29B6F6);
  
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color dividerColor = Color(0xFFBDBDBD);
  
  // Status Colors
  static const Color statusPending = Color(0xFFFFA726);
  static const Color statusApproved = Color(0xFF4CAF50);
  static const Color statusRejected = Color(0xFFE53935);
  static const Color statusUnderReview = Color(0xFF29B6F6);
  
  // Sync Status Colors
  static const Color syncPending = Color(0xFFFFA726);
  static const Color syncSynced = Color(0xFF4CAF50);
  static const Color syncFailed = Color(0xFFE53935);
}

// Text Styles
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    fontStyle: FontStyle.italic,
  );
  
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}

// Loan Schemes
class LoanSchemes {
  static const List<String> schemes = [
    'PMMY (Pradhan Mantri Mudra Yojana)',
    'Stand Up India',
    'PMEGP (Prime Minister Employment Generation Programme)',
    'Kisan Credit Card',
    'Agriculture Term Loan',
    'Dairy Development Scheme',
    'Poultry Farming Loan',
    'Self Help Group Loan',
    'Women Entrepreneurship Loan',
    'Other',
  ];
}

// Asset Categories
class AssetCategories {
  static const List<String> categories = [
    'Machinery & Equipment',
    'Vehicles',
    'Livestock',
    'Agricultural Tools',
    'Raw Materials',
    'Inventory',
    'Technology & Computers',
    'Furniture & Fixtures',
    'Building & Construction',
    'Other',
  ];
}

// User Roles
class UserRoles {
  static const String beneficiary = 'beneficiary';
  static const String fieldOfficer = 'officer'; // Alias for backward compatibility
  static const String officer = 'officer';
  static const String reviewer = 'reviewer';
  static const String admin = 'admin';
  
  static const List<String> allRoles = [
    beneficiary,
    officer,
    reviewer,
    admin,
  ];
  
  static String getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case beneficiary:
        return 'Beneficiary';
      case officer:
        return 'Field Officer';
      case reviewer:
        return 'Reviewer';
      case admin:
        return 'Administrator';
      default:
        return 'Unknown';
    }
  }
  
  // Authority levels for conflict resolution
  static int getAuthorityLevel(String role) {
    switch (role.toLowerCase()) {
      case admin:
        return 3;
      case reviewer:
        return 2;
      case officer:
        return 1;
      default:
        return 0;
    }
  }
}

// Submission Status
class SubmissionStatus {
  static const String pending = 'pending';
  static const String underReview = 'under_review';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

// Sync Status
class SyncStatus {
  static const String pending = 'pending';
  static const String synced = 'synced';
  static const String failed = 'failed';
}

// Media Types
class MediaTypes {
  static const String image = 'image';
  static const String video = 'video';
}

// Error Messages
class ErrorMessages {
  static const String networkError = 'Please check your internet connection';
  static const String serverError = 'Server error. Please try again later';
  static const String invalidOtp = 'Invalid OTP. Please try again';
  static const String otpExpired = 'OTP has expired. Please request a new one';
  static const String invalidMobileNumber = 'Please enter a valid 10-digit mobile number';
  static const String locationPermissionDenied = 'Location permission is required';
  static const String cameraPermissionDenied = 'Camera permission is required';
  static const String storagePermissionDenied = 'Storage permission is required';
  static const String fileTooLarge = 'File size exceeds the maximum limit';
  static const String invalidFileFormat = 'Invalid file format';
  static const String uploadFailed = 'Upload failed. Will retry when online';
  static const String syncFailed = 'Sync failed. Please try again';
}

// Success Messages
class SuccessMessages {
  static const String otpSent = 'OTP sent successfully';
  static const String loginSuccess = 'Login successful';
  static const String uploadSuccess = 'Media uploaded successfully';
  static const String savedLocally = 'Saved locally. Will sync when online';
  static const String syncSuccess = 'All data synced successfully';
  static const String approvalSuccess = 'Submission approved successfully';
  static const String rejectionSuccess = 'Submission rejected';
  static const String loanCreated = 'Loan created successfully';
}

// Validation Patterns
class ValidationPatterns {
  static final RegExp mobileNumber = RegExp(r'^[6-9]\d{9}$');
  static final RegExp email = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  static final RegExp aadhaar = RegExp(r'^\d{4}$'); // Last 4 digits
  static final RegExp pincode = RegExp(r'^\d{6}$');
  static final RegExp amount = RegExp(r'^\d+(\.\d{1,2})?$');
}

// Permission Types
class PermissionTypes {
  static const String camera = 'camera';
  static const String location = 'location';
  static const String storage = 'storage';
}

// Date Formats
class DateFormats {
  static const String displayDate = 'dd MMM yyyy';
  static const String displayDateTime = 'dd MMM yyyy, hh:mm a';
  static const String apiDate = 'yyyy-MM-dd';
  static const String apiDateTime = 'yyyy-MM-dd HH:mm:ss';
}
