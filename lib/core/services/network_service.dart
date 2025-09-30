import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/constants.dart';

class NetworkService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  final Connectivity _connectivity = Connectivity();

  NetworkService() {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add authentication token if available
          // final token = await _getAuthToken();
          // if (token != null) {
          //   options.headers['Authorization'] = 'Bearer $token';
          // }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (error, handler) {
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> isConnected() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Stream<ConnectivityResult> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  // Auth endpoints
  Future<ApiResponse> sendOTP(String mobileNumber) async {
    try {
      final response = await _dio.post('/auth/send-otp', data: {
        'mobile_number': mobileNumber,
      });
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> verifyOTP(String mobileNumber, String otp) async {
    try {
      final response = await _dio.post('/auth/verify-otp', data: {
        'mobile_number': mobileNumber,
        'otp': otp,
      });
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // User endpoints
  Future<ApiResponse> getUserProfile(int userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // Loan endpoints
  Future<ApiResponse> createLoan(Map<String, dynamic> loanData) async {
    try {
      final response = await _dio.post('/loans', data: loanData);
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> getLoans({int? beneficiaryId, String? status}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (beneficiaryId != null) queryParams['beneficiary_id'] = beneficiaryId;
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get('/loans', queryParameters: queryParams);
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // Media submission endpoints
  Future<ApiResponse> uploadMedia({
    required String filePath,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'metadata': jsonEncode(metadata),
      });

      final response = await _dio.post('/submissions/upload', data: formData);
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> getSubmissions({
    int? beneficiaryId,
    int? officerId,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (beneficiaryId != null) queryParams['beneficiary_id'] = beneficiaryId;
      if (officerId != null) queryParams['officer_id'] = officerId;
      if (status != null) queryParams['status'] = status;

      final response =
          await _dio.get('/submissions', queryParameters: queryParams);
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<ApiResponse> updateSubmissionStatus({
    required int submissionId,
    required String status,
    String? remarks,
  }) async {
    try {
      final response =
          await _dio.put('/submissions/$submissionId/status', data: {
        'status': status,
        'remarks': remarks,
      });
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // AI Validation endpoint
  Future<ApiResponse> validateMedia(int submissionId) async {
    try {
      final response = await _dio.post('/ai/validate/$submissionId');
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // Sync endpoints
  Future<ApiResponse> syncData(Map<String, dynamic> syncData) async {
    try {
      final response = await _dio.post('/sync', data: syncData);
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  ApiResponse _handleError(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return ApiResponse(
          success: false,
          message: 'Connection timeout',
        );
      } else if (error.type == DioExceptionType.connectionError) {
        return ApiResponse(
          success: false,
          message: ErrorMessages.networkError,
        );
      } else if (error.response != null) {
        return ApiResponse(
          success: false,
          message: error.response?.data['message'] ?? ErrorMessages.serverError,
          statusCode: error.response?.statusCode,
        );
      }
    }
    return ApiResponse(
      success: false,
      message: error.toString(),
    );
  }
}

class ApiResponse {
  final bool success;
  final String? message;
  final dynamic data;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.statusCode,
  });

  factory ApiResponse.fromResponse(Response response) {
    final responseData = response.data;
    return ApiResponse(
      success: responseData['success'] ?? true,
      message: responseData['message'],
      data: responseData['data'],
      statusCode: response.statusCode,
    );
  }
}
