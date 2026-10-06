import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';

class SessionProvider extends ChangeNotifier {
  final ApiClient api = ApiClient();
  static final FlutterSecureStorage _storage = FlutterSecureStorage();
  Map<String, dynamic>? user;
  Map<String, dynamic>? profile;
  bool busy = false;
  String? error;
  bool get isLoggedIn => user != null;
  bool get isAdmin => user?['role'] == 'admin';
  bool get mustChangePassword => user?['mustChangePassword'] == true;

  Future<void> restore() async {
    final saved = await _storage.read(key: 'academy.jwt');
    if (saved == null) return;
    api.token = saved;
    try {
      final data = await api.get('/auth/me');
      user = Map<String, dynamic>.from(data['user']);
      profile = data['profile'] == null
          ? null
          : Map<String, dynamic>.from(data['profile']);
    } catch (error) {
      final invalidSession = error is ApiException &&
          (error.statusCode == 401 || error.statusCode == 403);
      if (invalidSession) {
        await _storage.delete(key: 'academy.jwt');
        api.token = null;
      }
    }
    notifyListeners();
  }

  Future<bool> login(String identifier, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final data = await api.post(
          '/auth/login', {'identifier': identifier, 'password': password});
      api.token = data['token'];
      user = Map<String, dynamic>.from(data['user']);
      profile = data['profile'] == null
          ? null
          : Map<String, dynamic>.from(data['profile']);
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

  Future<void> logout() async {
    await _storage.delete(key: 'academy.jwt');
    api.token = null;
    user = null;
    profile = null;
    notifyListeners();
  }
}
