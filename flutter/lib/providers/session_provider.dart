import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';

class SessionProvider extends ChangeNotifier {
  final ApiClient api = ApiClient();
  static final FlutterSecureStorage _storage = FlutterSecureStorage();
  Map<String, dynamic>? user;
  Map<String, dynamic>? profile;
  Map<String, dynamic>? application;
  String? applicationPassword;
  Map<String, dynamic> settings = {};
  bool busy = false;
  bool restoring = true;
  String? error;
  bool get isLoggedIn => user != null;
  bool get hasPendingApplication => application != null && user == null;
  bool get isAdmin => user?['role'] == 'admin';
  bool get mustChangePassword => user?['mustChangePassword'] == true;

  Future<void> restore() async {
    await loadSettings();
    String? saved;
    try {
      saved = await _storage.read(key: 'academy.jwt');
    } catch (_) {
      // Some Android devices can reject an old/corrupt secure-storage entry.
      // Start signed out instead of crashing during app launch.
      await _clearStoredTokenSafely();
      restoring = false;
      notifyListeners();
      return;
    }
    if (saved == null) {
      restoring = false;
      notifyListeners();
      return;
    }
    api.token = saved;
    for (var attempt = 0; attempt < 3 && user == null; attempt++) {
      try {
        final data = await api.get('/auth/me');
        user = Map<String, dynamic>.from(data['user']);
        profile = data['profile'] == null ? null : Map<String, dynamic>.from(data['profile']);
      } catch (error) {
        final invalidSession = error is ApiException && (error.statusCode == 401 || error.statusCode == 403);
        if (invalidSession) {
          await _clearStoredTokenSafely();
          api.token = null;
          break;
        }
        if (attempt < 2) await Future<void>.delayed(Duration(seconds: attempt + 1));
      }
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> loadSettings() async {
    try {
      final data = await api.get('/content/settings');
      settings = Map<String, dynamic>.from(data);
      notifyListeners();
    } catch (_) {
      // Bundled branding remains available if the server is unavailable.
    }
  }

  void applySettings(Map<String, dynamic> value) {
    settings = value;
    notifyListeners();
  }

  Future<void> _clearStoredTokenSafely() async {
    try {
      await _storage.delete(key: 'academy.jwt');
    } catch (_) {
      // A storage cleanup failure must never prevent the login screen opening.
    }
  }

  Future<bool> login(String identifier, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final data = await api.post(
          '/auth/login', {'identifier': identifier, 'password': password});
      if (data['pendingApplication'] == true) {
        application = Map<String, dynamic>.from(data['application']);
        applicationPassword = password;
        return true;
      }
      api.token = data['token'];
      user = Map<String, dynamic>.from(data['user']);
      profile = data['profile'] == null
          ? null
          : Map<String, dynamic>.from(data['profile']);
      await loadSettings();
      await _storage.write(key: 'academy.jwt', value: api.token!);
      return true;
    } catch (e) {
      error = e is ApiException ? e.message : 'Unable to sign in';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(String newPassword) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final data =
          await api.post('/auth/change-password', {'newPassword': newPassword});
      user = Map<String, dynamic>.from(data['user']);
      return true;
    } catch (e) {
      error = e is ApiException ? e.message : 'Unable to change password';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> resubmitApplication(Map<String, dynamic> values) async {
    if (application == null || applicationPassword == null) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final data = await api.patch(
        '/auth/application/${application!['_id']}/resubmit',
        {...values, 'email': application!['email'], 'password': applicationPassword},
      );
      application = Map<String, dynamic>.from(data['application']);
      return true;
    } catch (e) {
      error = e is ApiException ? e.message : 'Unable to resubmit application';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> updateAdminAccount(String email, String newPassword) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final data = await api.patch('/auth/admin-account', {
        'email': email,
        'newPassword': newPassword,
      });
      user = Map<String, dynamic>.from(data['user']);
      return true;
    } catch (e) {
      error = e is ApiException ? e.message : 'Unable to update admin account';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await api.post('/auth/request-password-reset', {'email': email});
      return true;
    } catch (e) {
      error = e is ApiException ? e.message : 'Unable to send OTP';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email, String otp, String newPassword) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await api.post('/auth/reset-password', {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      });
      return true;
    } catch (e) {
      error = e is ApiException ? e.message : 'Unable to reset password';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _clearStoredTokenSafely();
    api.token = null;
    user = null;
    profile = null;
    application = null;
    applicationPassword = null;
    notifyListeners();
  }
}
