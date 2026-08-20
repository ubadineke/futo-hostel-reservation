import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/roost_api.dart';
import '../config/app_config.dart';
import '../demo/hostel_data.dart';

/// Holds the signed-in [Student] (null = signed out) and owns the auth flow.
///
/// On a successful sign-in it **bootstraps** the app: fetches the hostels (and
/// their room detail) into [HostelData] and the student's reservations into
/// [reservationsProvider], so the rest of the app keeps reading synchronously.
/// Live launches require this bootstrap to succeed; stale demo availability
/// must never be displayed as if it came from the server.
class SessionController extends Notifier<Student?> {
  @override
  Student? build() => null;

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> signIn({
    required String identifier,
    required String password,
    bool register = false,
    String? name,
    String? regNo,
    String? email,
    String? dept,
    String? level,
  }) async {
    if (AppConfig.useDemoData) {
      state = Student.demo();
      return null;
    }
    try {
      final api = ref.read(roostApiProvider);
      final auth = register
          ? await api.register(
              name: name!,
              regNo: regNo!,
              email: email!,
              dept: dept!,
              level: level!,
              password: password,
            )
          : await api.login(identifier, password);
      api.setToken(auth.token);
      try {
        await _bootstrap();
      } on ApiException catch (e) {
        _log('Bootstrap API error: ${e.statusCode} ${e.code} — ${e.message}');
        api.setToken(null);
        return 'Signed in, but could not load live hostel data: ${e.message}';
      } catch (e) {
        _log('Bootstrap connection error: $e');
        api.setToken(null);
        return 'Signed in, but could not load live hostel data. Check the API connection and try again.';
      }
      await ref.read(tokenStoreProvider).save(auth.token);
      state = auth.student;
      _log('Live bootstrap completed successfully.');
      return null;
    } on ApiException catch (e) {
      _log(
        'Authentication API error: ${e.statusCode} ${e.code} — ${e.message}',
      );
      return e.message;
    } catch (e) {
      _log('Authentication connection error: $e');
      return 'Could not reach the server. Check your connection and try again.';
    }
  }

  /// Restore a previous session after biometric unlock. Returns false if there
  /// is no stored token or it is no longer valid (caller should ask for a
  /// password sign-in). Always true in demo mode.
  Future<bool> restoreSession() async {
    if (AppConfig.useDemoData) {
      state = Student.demo();
      return true;
    }
    final token = await ref.read(tokenStoreProvider).read();
    if (token == null || token.isEmpty) return false;
    final api = ref.read(roostApiProvider)..setToken(token);
    try {
      final student = await api.me();
      await _bootstrap();
      state = student;
      _log('Stored session restored with live API data.');
      return true;
    } catch (e) {
      _log('Stored session bootstrap failed: $e');
      api.setToken(null);
      await ref.read(tokenStoreProvider).clear();
      state = null;
      return false;
    }
  }

  Future<void> signOut() async {
    if (!AppConfig.useDemoData) {
      final api = ref.read(roostApiProvider);
      try {
        await api.logout();
      } catch (_) {
        /* best effort */
      }
      api.setToken(null);
      await ref.read(tokenStoreProvider).clear();
    }
    state = null;
  }

  /// Updates the signed-in student's editable profile fields and immediately
  /// refreshes the profile tab from the server response.
  Future<String?> updateProfile({
    String? name,
    String? email,
    String? dept,
    String? level,
  }) async {
    if (AppConfig.useDemoData) {
      return 'Profile editing needs the live API.';
    }
    try {
      final student = await ref.read(roostApiProvider).updateProfile(
            name: name,
            email: email,
            dept: dept,
            level: level,
          );
      state = student;
      return null;
    } on ApiException catch (e) {
      _log('Profile update API error: ${e.statusCode} ${e.code} — ${e.message}');
      return e.message;
    } catch (e) {
      _log('Profile update connection error: $e');
      return 'Could not save your profile. Check your connection and try again.';
    }
  }

  /// Fill [HostelData] + [reservationsProvider] from the backend. Every request
  /// must succeed so a partial or unavailable backend can never leave static
  /// demo availability on screen.
  Future<void> _bootstrap() async {
    final api = ref.read(roostApiProvider);
    _log('Loading hostels from ${AppConfig.apiBaseUrl}...');
    final list = await api.hostels();
    _log('Loaded ${list.length} hostel summaries; loading room details...');
    final details = await Future.wait(list.map((h) => api.hostel(h.id)));
    final reservations = await api.reservations();

    HostelData.replaceHostels(details);
    ref.read(reservationsProvider.notifier).setAll(reservations);
    _log(
      'Loaded ${details.length} hostel details and ${reservations.length} reservations.',
    );
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[Roost] $message');
  }
}

final sessionProvider = NotifierProvider<SessionController, Student?>(
  SessionController.new,
);
