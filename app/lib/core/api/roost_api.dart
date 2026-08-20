import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../demo/hostel_data.dart';

/// A typed error carrying the backend's `{ error: { code, message } }` body
/// (see docs/BACKEND-README.md §9). [message] is safe to show to the user.
class ApiException implements Exception {
  ApiException(this.code, this.message, this.statusCode);
  final String code;
  final String message;
  final int statusCode;

  @override
  String toString() => 'ApiException($statusCode $code): $message';
}

/// Result of a successful login/register.
class AuthResult {
  AuthResult(this.token, this.student);
  final String token;
  final Student student;
}

/// Result of POST /reservations — the held reservation plus where to send the
/// student to actually pay for it (Paystack's hosted checkout, sandbox mode).
class ReservationCreateResult {
  ReservationCreateResult(this.reservation, this.authorizationUrl);
  final Reservation reservation;
  final String authorizationUrl;
}

/// The single client for the Roost REST API (base path `/api/v1`).
///
/// Holds the bearer token in memory for the app session; persistence across
/// restarts is handled separately by [TokenStore] (for biometric unlock).
class RoostApi {
  RoostApi(this._client);
  final http.Client _client;
  String? _token;

  void setToken(String? token) => _token = token;

  static const _timeout = Duration(seconds: 60); // Render free tier can cold-start

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('${AppConfig.apiBaseUrl}$path');
    if (query == null || query.isEmpty) return base;
    final q = <String, String>{};
    query.forEach((k, v) {
      if (v != null) q[k] = '$v';
    });
    return base.replace(queryParameters: q.isEmpty ? null : q);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async {
    final res =
        await _client.get(_uri(path, query), headers: _headers).timeout(_timeout);
    return _decode(res);
  }

  Future<dynamic> _post(String path, [Object? body]) async {
    final res = await _client
        .post(_uri(path),
            headers: _headers, body: body == null ? null : jsonEncode(body))
        .timeout(_timeout);
    return _decode(res);
  }

  Future<dynamic> _patch(String path, Object body) async {
    final res = await _client
        .patch(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    dynamic body;
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {/* non-JSON body */}
    }
    if (ok) return body;
    final err = (body is Map && body['error'] is Map)
        ? body['error'] as Map
        : null;
    throw ApiException(
      err?['code']?.toString() ?? 'HTTP_${res.statusCode}',
      err?['message']?.toString() ?? _friendly(res.statusCode),
      res.statusCode,
    );
  }

  String _friendly(int code) => switch (code) {
        400 || 422 => 'Please check the details and try again.',
        401 => 'Wrong credentials, or your session expired.',
        403 => 'You can only access your own data.',
        404 => 'Not found.',
        409 => 'That bed is no longer available.',
        >= 500 => 'The server had a problem. Please try again.',
        _ => 'Something went wrong (HTTP $code).',
      };

  // ---- auth ----
  Future<AuthResult> login(String identifier, String password) async {
    final j = await _post('/auth/login',
        {'identifier': identifier, 'password': password}) as Map<String, dynamic>;
    return AuthResult(
        j['token'] as String, Student.fromJson(j['student'] as Map<String, dynamic>));
  }

  Future<AuthResult> register({
    required String name,
    required String regNo,
    required String email,
    required String dept,
    required String level,
    required String password,
  }) async {
    final j = await _post('/auth/register', {
      'name': name,
      'regNo': regNo,
      'email': email,
      'dept': dept,
      'level': level,
      'password': password,
    }) as Map<String, dynamic>;
    return AuthResult(
        j['token'] as String, Student.fromJson(j['student'] as Map<String, dynamic>));
  }

  Future<Student> me() async {
    final j = await _get('/auth/me') as Map<String, dynamic>;
    // Spec returns StudentDto directly; tolerate a { student } wrapper too.
    final s = (j['student'] is Map ? j['student'] : j) as Map<String, dynamic>;
    return Student.fromJson(s);
  }

  Future<Student> updateProfile({
    String? name,
    String? email,
    String? dept,
    String? level,
  }) async {
    final body = <String, String>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (dept != null) body['dept'] = dept;
    if (level != null) body['level'] = level;
    final j = await _patch('/auth/me', body) as Map<String, dynamic>;
    final s = (j['student'] is Map ? j['student'] : j) as Map<String, dynamic>;
    return Student.fromJson(s);
  }

  Future<void> logout() async => _post('/auth/logout');

  // ---- hostels ----
  Future<List<Hostel>> hostels() async {
    final j = await _get('/hostels') as List<dynamic>;
    return j.map((e) => Hostel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Hostel> hostel(String id) async {
    final j = await _get('/hostels/$id') as Map<String, dynamic>;
    return Hostel.fromJson(j);
  }

  // ---- reservations ----
  Future<ReservationCreateResult> createReservation({
    required String hostelId,
    required String roomId,
    required int bed,
  }) async {
    final j = await _post('/reservations',
        {'hostelId': hostelId, 'roomId': roomId, 'bed': bed}) as Map<String, dynamic>;
    final reservation = Reservation.fromJson(j['reservation'] as Map<String, dynamic>);
    final authorizationUrl = (j['payment'] as Map<String, dynamic>)['authorizationUrl'] as String;
    return ReservationCreateResult(reservation, authorizationUrl);
  }

  Future<List<Reservation>> reservations() async {
    final j = await _get('/reservations') as List<dynamic>;
    return j.map((e) => Reservation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Reservation> reservation(String id) async {
    final j = await _get('/reservations/$id') as Map<String, dynamic>;
    return Reservation.fromJson(j);
  }

  Future<Reservation> cancelReservation(String id) async {
    final j = await _post('/reservations/$id/cancel') as Map<String, dynamic>;
    return Reservation.fromJson(j);
  }

  // ---- payments (Paystack, sandbox — real checkout via PaymentWebViewPage) ----

  /// Poll after checkout closes. No webhook — the server checks Paystack's
  /// verify endpoint live when this is called.
  Future<String> paymentStatus(String rrr) async {
    final j = await _get('/payments/$rrr/status') as Map<String, dynamic>;
    return (j['status'] ?? 'pending').toString();
  }

  /// Offline fallback that bypasses Paystack entirely — not used by the normal
  /// checkout flow, kept for demoing without depending on Paystack being reachable.
  Future<void> simulatePayment(String rrr, {bool success = true}) async =>
      _post('/payments/$rrr/simulate', {'outcome': success ? 'success' : 'failed'});
}

/// Persists the JWT across app restarts (Keychain on iOS, EncryptedSharedPrefs
/// on Android) so biometric unlock can restore the session.
class TokenStore {
  const TokenStore();
  static const _key = 'roost_jwt';
  static const _storage = FlutterSecureStorage();

  Future<String?> read() => _storage.read(key: _key);
  Future<void> save(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}

final roostApiProvider = Provider<RoostApi>((ref) {
  final api = RoostApi(http.Client());
  ref.onDispose(api._client.close);
  return api;
});

final tokenStoreProvider = Provider<TokenStore>((ref) => const TokenStore());
