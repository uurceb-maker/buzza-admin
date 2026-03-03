import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/admin_api.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _user;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get user => _user;
  String get userName => _user?['name'] ?? 'Admin';
  String get userEmail => _user?['email'] ?? '';

  final AdminApi _api = AdminApi();

  /// Normal login
  Future<void> login(String url, String username, String password, {bool rememberMe = true}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.login(url, username, password);
      _user = result['user'] as Map<String, dynamic>? ?? {};
      _isLoggedIn = true;

      // Save session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('site_url', url);
      await prefs.setString('token', _api.token);
      await prefs.setString('user_name', _user?['name'] ?? '');
      await prefs.setString('user_email', _user?['email'] ?? '');
      if (rememberMe) {
        await prefs.setBool('remember_me', true);
        await prefs.setString('saved_username', username);
        await prefs.setString('saved_password', password);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Auto-login on startup
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final token = prefs.getString('token') ?? '';
    final siteUrl = prefs.getString('site_url') ?? '';

    if (token.isEmpty || siteUrl.isEmpty) return false;

    // Try token verification first
    _api.setBaseUrl(siteUrl);
    _api.setToken(token);

    try {
      final result = await _api.verify();
      if (result['valid'] == true) {
        _user = result['user'] as Map<String, dynamic>? ?? {};
        _isLoggedIn = true;
        notifyListeners();
        return true;
      }
    } catch (_) {}

    // Token expired → try re-login with saved credentials
    if (rememberMe) {
      final username = prefs.getString('saved_username') ?? '';
      final password = prefs.getString('saved_password') ?? '';
      if (username.isNotEmpty && password.isNotEmpty) {
        try {
          await login(siteUrl, username, password, rememberMe: true);
          return true;
        } catch (_) {}
      }
    }

    return false;
  }

  Future<void> logout() async {
    _user = null;
    _isLoggedIn = false;
    _api.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
