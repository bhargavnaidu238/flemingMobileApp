import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ================== API CONFIG ==================
class ApiConfig {
  static const String _localWeb = 'http://localhost:8080';
  static const String _localAndroid = 'http://10.0.2.2:8080';
  static const String _altLocal = 'http://127.0.0.1:8000';
  static const String _production =
      'https://test-host-server-tamg.onrender.com';

  static const String _razorpayTestKey = 'rzp_test_RyBLHvNxl52vtv';
  static const String _razorpayLiveKey = 'rzp_live_xxxxxxxx';

  static String get baseUrl {
    if (kReleaseMode) return _production;
    if (kIsWeb) return _localWeb;
    return _localAndroid;
  }

  static String get alternateLocalUrl => _altLocal;

  static String get razorpayKeyId {
    if (kReleaseMode) return _razorpayLiveKey;
    return _razorpayTestKey;
  }
}

/// ================== MAIN API SERVICE ==================
class ApiService {
  /// ================= AUTH STORAGE KEYS =================
  static const String _tokenKey = "auth_token";
  static const String _emailKey = "auth_email";
  static const String _userIdKey = "auth_userId";

  static String? _cachedToken;
  static String? _cachedEmail;
  static String? _cachedUserId;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    _cachedEmail = prefs.getString(_emailKey);
    _cachedUserId = prefs.getString(_userIdKey);
    debugPrint("ApiService: Data loaded. LoggedIn: ${isLoggedIn()}");
  }

  static Future<void> saveAuthData({
    required String token,
    required String email,
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_userIdKey, userId);

    _cachedToken = token;
    _cachedEmail = email;
    _cachedUserId = userId;
  }

  static String? getToken() => _cachedToken;
  static String? getEmail() => _cachedEmail;
  static String? getUserId() => _cachedUserId;

  static bool isLoggedIn() => _cachedToken != null && _cachedToken!.isNotEmpty;

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_userIdKey);
    _cachedToken = null;
    _cachedEmail = null;
    _cachedUserId = null;
    debugPrint("ApiService: User logged out and cache cleared.");
  }

  /// ================= EMAIL OTP =================

  static Future<bool> sendEmailOtp(String email) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/send-email-otp');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
          "type": "send_otp"
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Send OTP Error: $e");
      return false;
    }
  }

  static Future<bool> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/verify-email-otp');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
          "otp": otp.trim(),
          "type": "verify_otp"
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Verify OTP Error: $e");
      return false;
    }
  }

  static Future<int> sendEmailOtpStatus(String email) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/send-email-otp');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
          "type": "send_otp"
        }),
      );
      return response.statusCode;
    } catch (e) {
      debugPrint("Send OTP Error: $e");
      return 500;
    }
  }

  /// ================= REGISTER =================
  static Future<bool> registerUser({
    required String email,
    required String firstName,
    required String lastName,
    required String gender,
    required String mobile,
    required String address,
    required String password,
    required String consent,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/register');
    final body = jsonEncode({
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'mobile': mobile,
      'address': address,
      'password': password,
      'consent': consent,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Register Error: $e');
      return false;
    }
  }

  /// ================= LOGIN =================
  static Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/login');
    final body = jsonEncode({
      'email': email,
      'password': password,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = data['token'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        final userId = data['userId']?.toString() ?? '';

        await saveAuthData(
          token: token,
          email: email,
          userId: userId,
        );

        return {
          'email': email,
          'userId': userId,
          'token': token,
          ...data,
        };
      }
      return {"error": data['error'] ?? "login_failed"};
    } catch (e) {
      debugPrint('Login Error: $e');
      return {"error": "connection_error"};
    }
  }

  /// ================= FORGOT PASSWORD =================
  static Future<Map<String, dynamic>> verifyForgotPassword({
    required String email,
    required String mobile,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/app/forgot-password/verify');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
          "mobile": mobile.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {"matched": data['matched'] == true};
      }
    } catch (e) {
      debugPrint('Verify Forgot Password Error: $e');
    }
    return {"matched": false};
  }

  static Future<Map<String, dynamic>> changePassword({
    required String email,
    required String newPassword,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/app/forgot-password/change');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
          "newPassword": newPassword,
        }),
      );
      return {"success": response.statusCode == 200};
    } catch (e) {
      debugPrint('Change Password Error: $e');
      return {"success": false};
    }
  }

  static Future<bool> changePasswordWithCurrent({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/app/change-password');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
          "currentPassword": currentPassword,
          "newPassword": newPassword,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      debugPrint('Change Password (Profile) Error: $e');
    }
    return false;
  }

  static Map<String, String> getAuthHeaders() {
    final token = getToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }
}

/// ================= PROFILE SERVICE =================
class ProfileApiService {
  static Future<Map<String, dynamic>?> fetchProfile({
    required String email,
  }) async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/profile?email=${Uri.encodeComponent(email)}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        return {
          "userId": data['userId']?.toString() ?? '',
          "email": data['email'] ?? email,
          "firstName": data['firstName'] ?? '',
          "lastName": data['lastName'] ?? '',
          "phone": data['phone'] ?? '',
          "address": data['address'] ?? '',
        };
      }
    } catch (e) {
      debugPrint('FetchProfile Error: $e');
    }
    return null;
  }

  static Future<bool> updateProfile({
    required String email,
    required String userId,
    required String firstName,
    required String lastName,
    required String phone,
    required String address,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/profile');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "userId": userId,
          "firstName": firstName,
          "lastName": lastName,
          "phone": phone,
          "address": address,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('UpdateProfile Error: $e');
      return false;
    }
  }

  static Future<bool> deactivateAccount({
    required String email,
    required String userId,
    required String status,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/profile');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
          "userId": userId.trim(),
          "status": status.trim(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Deactivate Error: $e');
      return false;
    }
  }
}