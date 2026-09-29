import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/errors.dart';

class ApiClient {
  ApiClient({this.onUnauthorized});

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userDataKey = 'auth_user_data';
  void Function()? onUnauthorized;

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<String?> getUserData() => _storage.read(key: _userDataKey);
  Future<void> saveUserData(String data) => _storage.write(key: _userDataKey, value: data);
  Future<void> clearUserData() => _storage.delete(key: _userDataKey);
  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userDataKey);
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path) async {
    try {
      final res = await http
          .get(_uri(path), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      return _decode(res);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(humanizeError(e));
    }
  }

  Future<dynamic> send(String method, String path, {Map<String, dynamic>? body, bool auth = true}) async {
    try {
      final headers = await _headers(auth: auth);
      late http.Response res;
      final uri = _uri(path);
      final encoded = body == null ? null : jsonEncode(body);
      switch (method) {
        case 'POST':
          res = await http.post(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 15));
          break;
        case 'PATCH':
          res = await http.patch(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
          break;
        default:
          throw ApiException('Unsupported method');
      }
      return _decode(res);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(humanizeError(e));
    }
  }

  dynamic _decode(http.Response res) {
    dynamic json;
    try {
      json = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    } catch (_) {
      if (res.statusCode >= 400) {
        if (res.statusCode == 401) {
          clearToken();
          onUnauthorized?.call();
        }
        throw ApiException(
          res.statusCode >= 500
              ? 'Something went wrong on the server. Please try again.'
              : 'Request failed with status ${res.statusCode}',
          status: res.statusCode,
        );
      }
      throw ApiException('Unexpected server response format.');
    }

    if (json is Map) {
      final success = json['success'];
      final message = json['message']?.toString() ??
          json['error']?['message']?.toString() ??
          'Request failed';
      final code = json['error']?['code']?.toString();
      final details = json['error']?['details'];

      if (res.statusCode >= 400 || success == false) {
        if (res.statusCode == 401) {
          clearToken();
          onUnauthorized?.call();
        }
        throw ApiException(message, status: res.statusCode, code: code, details: details);
      }

      if (json.containsKey('data')) {
        return json['data'];
      }
      return json;
    }

    if (res.statusCode >= 400) {
      if (res.statusCode == 401) {
        clearToken();
        onUnauthorized?.call();
      }
      throw ApiException('Request failed with status ${res.statusCode}', status: res.statusCode);
    }

    return json;
  }
}
