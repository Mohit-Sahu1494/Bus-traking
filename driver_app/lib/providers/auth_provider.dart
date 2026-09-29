import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/errors.dart';
import '../services/api_client.dart';

class DriverProfile {
  DriverProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.busNumber,
    required this.totalTrips,
    required this.completedTrips,
    required this.skippedStops,
  });
  final String name, email, phone, busNumber;
  final int totalTrips, completedTrips, skippedStops;

  factory DriverProfile.fromJson(Map<String, dynamic> json) => DriverProfile(
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        busNumber: json['busNumber']?.toString() ?? '',
        totalTrips: (json['totalTrips'] as num?)?.toInt() ?? 0,
        completedTrips: (json['completedTrips'] as num?)?.toInt() ?? 0,
        skippedStops: (json['skippedStops'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'busNumber': busNumber,
        'totalTrips': totalTrips,
        'completedTrips': completedTrips,
        'skippedStops': skippedStops,
      };
}

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api);
  final ApiClient _api;
  DriverProfile? profile;
  bool loading = true;
  bool get isAuthenticated => profile != null;

  Future<void> restore() async {
    loading = true;
    notifyListeners();
    try {
      final token = await _api.getToken();
      if (token == null) {
        profile = null;
        return;
      }

      // Immediately restore cached driver profile so driver stays logged in
      final cachedJson = await _api.getProfileData();
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          profile = DriverProfile.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
        } catch (_) {}
      }

      try {
        await refresh();
      } on ApiException catch (e) {
        if (e.status == 401) {
          await _api.clearToken();
          profile = null;
        }
      } catch (_) {
        // Keep cached profile on offline/timeout
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final data = await _api.send('POST', '/api/auth/driver/login', body: {'email': email, 'password': password}, auth: false);
    await _api.saveToken(data['token'] as String);
    await refresh();
  }

  Future<void> refresh() async {
    final data = await _api.get('/api/driver/profile');
    profile = DriverProfile.fromJson(Map<String, dynamic>.from(data as Map));
    await _api.saveProfileData(jsonEncode(profile!.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.clearToken();
    profile = null;
    notifyListeners();
  }
}
