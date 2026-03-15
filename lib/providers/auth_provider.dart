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
  List<String> get userRoles {
    final raw = _user?['roles'];
    if (raw is! List) return const [];
    return raw.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
  }

  String get primaryRole {
    final explicit = '${_user?['primary_role'] ?? ''}'.trim();
    if (explicit.isNotEmpty) return explicit;
    return userRoles.isNotEmpty ? userRoles.first : '';
  }

  bool hasRole(String role) => userRoles.contains(role);
  bool get canManageOptions {
    final perms = _user?['permissions'];
    if (perms is Map) {
      final value = perms['manage_options'];
      if (_asBool(value)) return true;
    }
    if (_asBool(_user?['manage_options'])) return true;
    return hasRole('administrator');
  }

  final AdminApi _api = AdminApi();

  Map<String, dynamic> _extractUserFromResult(Map<String, dynamic> result) {
    final directUser = result['user'];
    if (directUser is Map) {
      return Map<String, dynamic>.from(directUser);
    }

    final data = result['data'];
    if (data is Map) {
      final nestedUser = data['user'];
      if (nestedUser is Map) {
        return Map<String, dynamic>.from(nestedUser);
      }
      return Map<String, dynamic>.from(data);
    }

    return {};
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '$value'.trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }

  /// Normal login
  Future<void> login(String url, String username, String password,
      {bool rememberMe = true}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.login(url, username, password);
      _user = _extractUserFromResult(result);
      _isLoggedIn = true;

      // Save session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('site_url', url);
      await prefs.setString('api_base_url', _api.baseUrl);
      await prefs.setString('token', _api.token);
      await prefs.setString('user_name', _user?['name'] ?? '');
      await prefs.setString('user_email', _user?['email'] ?? '');
      if (rememberMe) {
        await prefs.setBool('remember_me', true);
        await prefs.setString('saved_username', username);
        await prefs.setString('saved_password', password);
      }
    } catch (_) {
      _user = null;
      _isLoggedIn = false;
      _api.clearSession();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      rethrow;
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
    final siteUrl =
        prefs.getString('api_base_url') ?? prefs.getString('site_url') ?? '';

    if (token.isEmpty || siteUrl.isEmpty) return false;

    // Try token verification first
    _api.setBaseUrl(siteUrl);
    _api.setToken(token);

    try {
      final result = await _api.verify();
      if (result['valid'] == true) {
        _user = _extractUserFromResult(result);
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
