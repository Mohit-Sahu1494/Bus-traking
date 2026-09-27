import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../core/errors.dart';

class ApiClient {
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

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
      final res = await http.get(_uri(path), headers: await _headers()).timeout(const Duration(seconds: 15));
      return _decode(res);
    } catch (e) {
      throw ApiException(humanizeError(e));
    }
  }

  Future<dynamic> send(String method, String path, {Map<String, dynamic>? body, bool auth = true}) async {
    try {
      final headers = await _headers(auth: auth);
      final uri = _uri(path);
      final encoded = body == null ? null : jsonEncode(body);
      late http.Response res;
      if (method == 'POST') {
        res = await http.post(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 15));
      } else if (method == 'PATCH') {
        res = await http.patch(uri, headers: headers, body: encoded).timeout(const Duration(seconds: 15));
      } else {
        res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
      }
      return _decode(res);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(humanizeError(e));
    }
  }

  dynamic _decode(http.Response res) {
    final json = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final message = json is Map ? (json['error']?['message'] ?? 'Request failed') : 'Request failed';
      throw ApiException(message.toString(), status: res.statusCode);
    }
    if (json is Map && json['data'] != null) return json['data'];
    return json;
  }
}
