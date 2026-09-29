import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/fcm_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api);

  final ApiClient _api;
  StudentUser? user;
  bool loading = true;
  String? error;

  bool get isAuthenticated => user != null;

  Future<void> restore() async {
    loading = true;
    notifyListeners();
    try {
      final token = await _api.getToken();
      if (token == null) {
        user = null;
        return;
      }

      // Immediately restore cached user profile so student stays logged in
      final cachedJson = await _api.getUserData();
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          user = StudentUser.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
        } catch (_) {}
      }

      // Refresh profile in background
      try {
        final data = await _api.get('/api/student/profile');
        user = StudentUser.fromJson(Map<String, dynamic>.from(data as Map));
        await _api.saveUserData(jsonEncode(user!.toJson()));
        unawaited(_registerFcm());
      } on ApiException catch (e) {
        if (e.status == 401) {
          await _api.clearToken();
          user = null;
        } else {
          error = e.message;
        }
      } catch (_) {
        // Keep cached user on offline/timeout
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    error = null;
    notifyListeners();
    final data = await _api.send('POST', '/api/auth/student/login', body: {
      'email': email.trim(),
      'password': password,
    }, auth: false);
    await _api.saveToken(data['token'] as String);
    user = StudentUser.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    await _api.saveUserData(jsonEncode(user!.toJson()));
    unawaited(_registerFcm());
    notifyListeners();
  }

  Future<Map<String, dynamic>> register({
    required String name,
    String? enrollmentNumber,
    required String email,
    required String password,
  }) async {
    error = null;
    final body = <String, dynamic>{
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
    };
    if (enrollmentNumber != null && enrollmentNumber.trim().isNotEmpty) {
      body['enrollmentNumber'] = enrollmentNumber.trim();
    }
    final data = await _api.send('POST', '/api/auth/student/register', body: body, auth: false);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> verifyOtp({
    required String email,
    required String otp,
  }) async {
    error = null;
    final data = await _api.send(
      'POST',
      '/api/auth/student/verify-otp',
      body: {
        'email': email.trim(),
        'otp': otp.trim(),
      },
      auth: false,
    );
    final map = Map<String, dynamic>.from(data as Map);
    if (map['token'] != null) {
      await _api.saveToken(map['token'] as String);
    }
    if (map['user'] != null) {
      user = StudentUser.fromJson(Map<String, dynamic>.from(map['user'] as Map));
      await _api.saveUserData(jsonEncode(user!.toJson()));
    } else {
      await refreshProfile();
    }
    unawaited(_registerFcm());
    notifyListeners();
  }

  Future<String> resendOtp({required String email}) async {
    final data = await _api.send(
      'POST',
      '/api/auth/student/resend-otp',
      body: {'email': email.trim()},
      auth: false,
    );
    final map = Map<String, dynamic>.from(data as Map);
    return map['email']?.toString() ?? email;
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    error = null;
    final data = await _api.send(
      'POST',
      '/api/auth/student/forgot-password',
      body: {'email': email.trim()},
      auth: false,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<String> resendResetOtp({required String email}) async {
    final data = await _api.send(
      'POST',
      '/api/auth/student/resend-reset-otp',
      body: {'email': email.trim()},
      auth: false,
    );
    final map = Map<String, dynamic>.from(data as Map);
    return map['email']?.toString() ?? email;
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    error = null;
    final data = await _api.send(
      'POST',
      '/api/auth/student/reset-password',
      body: {
        'email': email.trim(),
        'otp': otp.trim(),
        'password': newPassword,
      },
      auth: false,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  void handleSessionExpired() {
    _api.clearToken();
    user = null;
    error = 'Your session has expired. Please login again.';
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final data = await _api.get('/api/student/profile');
    user = StudentUser.fromJson(Map<String, dynamic>.from(data as Map));
    await _api.saveUserData(jsonEncode(user!.toJson()));
    notifyListeners();
  }

  Future<void> updatePickup(String stopId) async {
    await _api.send('PATCH', '/api/student/pickup-stop', body: {'stopId': stopId});
    await refreshProfile();
  }

  Future<void> logout() async {
    try {
      final token = FcmService().currentToken;
      if (token != null) {
        await _api.send('DELETE', '/api/student/fcm-token', body: {'token': token});
      }
    } catch (_) {}
    await _api.clearToken();
    user = null;
    notifyListeners();
  }

  Future<void> _registerFcm() async {
    final fcm = FcmService();
    fcm.onTokenRefreshed = (newToken) async {
      try {
        await _api.send('POST', '/api/student/fcm-token', body: {'token': newToken});
      } catch (_) {}
    };

    final token = await fcm.initAndGetToken();
    if (token != null) {
      try {
        await _api.send('POST', '/api/student/fcm-token', body: {'token': token});
      } catch (_) {}
    }
  }
}
