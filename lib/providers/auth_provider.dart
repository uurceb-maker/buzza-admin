import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/admin_api.dart';

/// Thrown when server requires OTP verification before completing login.
class OtpRequiredException implements Exception {
  final String otpRedirectUrl;
  final String sessionToken;
  final String message;

  OtpRequiredException({
    required this.otpRedirectUrl,
    required this.sessionToken,
    this.message = 'OTP doğrulaması gerekli.',
  });

  @override
  String toString() => message;
}

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _user;

  // OTP state
  String? _pendingOtpRedirect;
  String? _pendingOtpSession;
  String? _pendingSiteUrl;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get user => _user;
  String get userName => _user?['name'] ?? 'Admin';
  String get userEmail => _user?['email'] ?? '';

  // OTP getters
  String? get pendingOtpRedirect => _pendingOtpRedirect;
  String? get pendingOtpSession => _pendingOtpSession;
  String? get pendingSiteUrl => _pendingSiteUrl;
  bool get hasOtpPending => _pendingOtpRedirect != null;

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
      // ─── Adım 1: Tek AJAX isteğiyle OTP kontrolü ───
      // Karmaşık login zincirini atla — doğrudan sunucuya sor
      final otpCheck = await _quickOtpCheck(url, username, password);
      if (otpCheck != null && _isOtpRequired(otpCheck)) {
        // Debug: sunucudan gelen veriyi logla
        debugPrint('🔐 OTP RAW DATA: $otpCheck');
        _pendingOtpRedirect = _extractOtpRedirect(otpCheck);
        _pendingOtpSession = _extractOtpSession(otpCheck);
        debugPrint('🔐 OTP REDIRECT: $_pendingOtpRedirect');
        debugPrint('🔐 OTP SESSION: $_pendingOtpSession');
        _pendingSiteUrl = url;
        _isLoading = false;
        notifyListeners();
        throw OtpRequiredException(
          otpRedirectUrl: _pendingOtpRedirect ?? '',
          sessionToken: _pendingOtpSession ?? '',
        );
      }

      // quickOtpCheck başarılı login döndüyse login zincirini atla
      Map<String, dynamic>? result;
      if (otpCheck != null && otpCheck['_quick_login_success'] == true) {
        debugPrint('✅ quickOtpCheck başarılı — login zinciri atlanıyor');
        result = otpCheck;
      } else {
        // ─── Adım 2: Normal login zinciri ───
        result = await _api.login(url, username, password);
      }

      // OTP kontrolünü burada da yap (yedek)
      if (_isOtpRequired(result)) {
        _pendingOtpRedirect = _extractOtpRedirect(result);
        _pendingOtpSession = _extractOtpSession(result);
        _pendingSiteUrl = url;
        _isLoading = false;
        notifyListeners();
        throw OtpRequiredException(
          otpRedirectUrl: _pendingOtpRedirect ?? '',
          sessionToken: _pendingOtpSession ?? '',
        );
      }

      _user = _extractUserFromResult(result);
      _isLoggedIn = true;
      _clearOtpState();

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
    } on OtpRequiredException {
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      // Error mesajında OTP redirect bilgisi var mı kontrol et
      final errorStr = '$e';
      if (errorStr.contains('bto_otp_required') ||
          errorStr.contains('otp_redirect') ||
          errorStr.contains('Telegram doğrulama')) {
        _pendingSiteUrl = url;
        // URL'yi hatadan parse etmeye çalış
        final redirectMatch = RegExp(r'otp_redirect[":\s]+([^"\s,}]+)').firstMatch(errorStr);
        final sessionMatch = RegExp(r'session_token[=&]([^&"\s]+)').firstMatch(errorStr);
        _pendingOtpRedirect = redirectMatch?.group(1);
        _pendingOtpSession = sessionMatch?.group(1);
        _isLoading = false;
        notifyListeners();
        throw OtpRequiredException(
          otpRedirectUrl: _pendingOtpRedirect ?? '',
          sessionToken: _pendingOtpSession ?? '',
          message: 'Telegram doğrulama kodu gönderildi.',
        );
      }
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

  /// Doğrudan tek AJAX POST — OTP gerekip gerekmediğini hızlıca kontrol eder
  /// Eğer OTP gerekmiyorsa ve başarılı token aldıysa, login zincirini atlayabiliriz
  Future<Map<String, dynamic>?> _quickOtpCheck(
      String url, String username, String password) async {
    try {
      final cleanUrl = url
          .replaceAll(RegExp(r'/wp-admin.*$', caseSensitive: false), '')
          .replaceAll(RegExp(r'/wp-json.*$', caseSensitive: false), '')
          .replaceAll(RegExp(r'/+$'), '');
      final ajaxUri = Uri.parse('$cleanUrl/wp-admin/admin-ajax.php');
      final siteUri = Uri.parse(cleanUrl);
      final origin = '${siteUri.scheme}://${siteUri.authority}';

      final response = await http.post(
        ajaxUri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
          'Accept': 'application/json, text/plain, */*',
          'X-Requested-With': 'XMLHttpRequest',
          'Origin': origin,
          'Referer': '$origin/',
        },
        body: {
          'action': 'buzza_admin_login',
          'username': username,
          'password': password,
        },
      ).timeout(const Duration(seconds: 15));

      final body = utf8.decode(response.bodyBytes).trim();
      if (body.isEmpty || body.startsWith('<')) return null;

      final decoded = json.decode(body);
      if (decoded is! Map<String, dynamic>) return null;

      // OTP gerekli mi? — Doğrudan döndür, login() metodu _isOtpRequired ile kontrol edecek
      if (_isOtpRequired(decoded)) {
        debugPrint('🔐 quickOtpCheck: OTP gerekli yanıtı alındı');
        return decoded;
      }

      // OTP gerekmiyorsa ve başarılı token aldıysa, login zincirini atla
      if (decoded['success'] == true) {
        final nestedData = decoded['data'];
        final tokenSource = nestedData is Map ? nestedData : decoded;
        final token = '${tokenSource['token'] ?? tokenSource['access_token'] ?? ''}'.trim();
        if (token.isNotEmpty) {
          debugPrint('✅ quickOtpCheck: Başarılı login — login zinciri atlanıyor');
          _api.setBaseUrl('$cleanUrl/wp-json/buzza-admin/v1');
          _api.setToken(token);
          // _quickOtpCheck null olmayan non-OTP sonuç döndürdüğünde
          // login() metodu bunu başarılı login olarak işleyecek
          return <String, dynamic>{
            ...decoded,
            '_quick_login_success': true,
            'token': token,
          };
        }
      }

      return decoded;
    } catch (_) {
      // OTP kontrol başarısız — normal login zincirine devam edecek
    }
    return null;
  }

  // ─── OTP Helpers ───────────────────────────────────

  bool _isOtpRequired(Map<String, dynamic> data) {
    // Düz yapı: {code: 'bto_otp_required', ...}
    if (data['code'] == 'bto_otp_required') return true;
    // wp_send_json_error yapısı: {success: false, data: {code: 'bto_otp_required', ...}}
    final nested = data['data'];
    if (nested is Map) {
      if (nested['code'] == 'bto_otp_required') return true;
      if (nested['otp_redirect'] != null) return true;
      if (nested['otp_required'] == true) return true;
      // Derin yapı: data.data.otp_redirect
      final deep = nested['data'];
      if (deep is Map) {
        if (deep['otp_redirect'] != null) return true;
        if (deep['code'] == 'bto_otp_required') return true;
      }
    }
    // wp_send_json_success formatı: {success: true, data: {otp_required: true}}
    if (data['success'] == true && nested is Map && nested['otp_required'] == true) return true;
    // JSON string olarak gelmiş olabilir — hata mesajında kontrol et
    final str = '$data';
    if (str.contains('bto_otp_required') || str.contains('otp_redirect')) return true;
    return false;
  }

  String? _extractOtpRedirect(Map<String, dynamic> data) {
    // Düz: data['otp_redirect']
    if (data['otp_redirect'] != null) return '${data['otp_redirect']}';
    final nested = data['data'];
    if (nested is Map) {
      // data.otp_redirect
      if (nested['otp_redirect'] != null) return '${nested['otp_redirect']}';
      // data.data.otp_redirect (wp_send_json_error sarmalı)
      final deep = nested['data'];
      if (deep is Map && deep['otp_redirect'] != null) return '${deep['otp_redirect']}';
    }
    // Son çare: tüm JSON string'inde URL'yi bul
    final str = '$data';
    final match = RegExp(r'otp_redirect["\s:]+([^"\s,}]+)').firstMatch(str);
    return match?.group(1);
  }

  String? _extractOtpSession(Map<String, dynamic> data) {
    // 1. Redirect URL'den çıkar
    final redirect = _extractOtpRedirect(data) ?? '';
    final urlMatch = RegExp(r'session_token[=]([^&\s"]+)').firstMatch(redirect);
    if (urlMatch != null) return Uri.decodeComponent(urlMatch.group(1)!);

    // 2. JSON data yapısından direkt al (tüm seviyelerde ara)
    if (data['session_token'] != null) return '${data['session_token']}';
    final nested = data['data'];
    if (nested is Map) {
      if (nested['session_token'] != null) return '${nested['session_token']}';
      final deep = nested['data'];
      if (deep is Map && deep['session_token'] != null) return '${deep['session_token']}';
    }

    // 3. Son çare: tüm JSON string'inde regex ile bul
    final str = '$data';
    final strMatch = RegExp(r'session_token[="\s:]+([a-zA-Z0-9_-]{20,})').firstMatch(str);
    return strMatch?.group(1);
  }

  void _clearOtpState() {
    _pendingOtpRedirect = null;
    _pendingOtpSession = null;
    _pendingSiteUrl = null;
  }

  void clearOtpPending() {
    _clearOtpState();
    notifyListeners();
  }

  Future<void> verifyOtp(String code) async {
    if (_pendingSiteUrl == null || _pendingOtpSession == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _api.verifyOtp(_pendingSiteUrl!, _pendingOtpSession!, code);
      _user = _extractUserFromResult(result);
      _isLoggedIn = true;
      _clearOtpState();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// OTP doğrulama başarılı — token ve kullanıcı verilerini kaydet
  Future<void> completeOtpLogin({
    required String token,
    required String siteUrl,
    String? expiresAt,
    Map<String, dynamic>? userData,
  }) async {
    final cleanUrl = siteUrl
        .replaceAll(RegExp(r'/wp-admin.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'/wp-json.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'/+$'), '');

    _api.setToken(token);

    // Doğrulama: önce buzza-security/v1 dene (JWT token burada issued),
    // başarısız olursa buzza-admin/v1 dene (HMAC token burada kayıtlı)
    Map<String, dynamic>? verifiedUser;
    for (final ns in const ['buzza-security/v1', 'buzza-admin/v1']) {
      _api.setBaseUrl('$cleanUrl/wp-json/$ns');
      try {
        final result = await _api.verify();
        if (result['valid'] == true && result['user'] != null) {
          verifiedUser = _extractUserFromResult(result);
          break;
        }
      } catch (_) {
        // Bu namespace'te verify başarısız — bir sonrakini dene
      }
    }

    // Verify hangi namespace'te başarılı olursa olsun,
    // baseUrl'yi buzza-admin/v1'e ayarla — tüm admin endpoints burada
    _api.setBaseUrl('$cleanUrl/wp-json/buzza-admin/v1');

    if (verifiedUser != null && verifiedUser.isNotEmpty) {
      _user = verifiedUser;
    } else if (userData != null && userData.isNotEmpty) {
      _user = userData;
    } else {
      _user = {};
    }

    _isLoggedIn = true;
    _clearOtpState();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('site_url', cleanUrl);
    await prefs.setString('api_base_url', _api.baseUrl);
    await prefs.setString('user_name', _user?['name'] ?? _user?['login'] ?? '');
    await prefs.setString('user_email', _user?['email'] ?? '');
    await prefs.setBool('remember_me', true);

    notifyListeners();
  }

  Future<void> resendOtp() async {
    if (_pendingSiteUrl == null || _pendingOtpSession == null) return;
    await _api.resendOtp(_pendingSiteUrl!, _pendingOtpSession!);
  }

  /// Auto-login on startup
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final savedBaseUrl = prefs.getString('api_base_url') ?? '';
    final savedSiteUrl = prefs.getString('site_url') ?? '';

    if (token.isEmpty || (savedBaseUrl.isEmpty && savedSiteUrl.isEmpty)) {
      return false;
    }

    _api.setToken(token);

    // Kayıtlı baseUrl ile dene
    if (savedBaseUrl.isNotEmpty) {
      _api.setBaseUrl(savedBaseUrl);
      try {
        final result = await _api.verify();
        if (result['valid'] == true) {
          _user = _extractUserFromResult(result);
          _isLoggedIn = true;
          // Admin endpoint'leri buzza-admin/v1'de — her zaman oraya set et
          final adminUrl = savedBaseUrl.contains('buzza-admin/v1')
              ? savedBaseUrl
              : savedBaseUrl.replaceAll(RegExp(r'buzza-security/v1|buzza/admin/v1'), 'buzza-admin/v1');
          _api.setBaseUrl(adminUrl);
          await prefs.setString('api_base_url', adminUrl);
          notifyListeners();
          return true;
        }
      } catch (_) {}
    }

    // Farklı namespace'lerle dene (OTP token buzza-security'de, normal token buzza-admin'de)
    final cleanUrl = (savedSiteUrl.isNotEmpty ? savedSiteUrl : savedBaseUrl)
        .replaceAll(RegExp(r'/wp-json.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'/wp-admin.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'/+$'), '');

    for (final ns in const ['buzza-security/v1', 'buzza-admin/v1']) {
      final candidateUrl = '$cleanUrl/wp-json/$ns';
      if (candidateUrl == savedBaseUrl) continue; // Zaten denendi
      _api.setBaseUrl(candidateUrl);
      try {
        final result = await _api.verify();
        if (result['valid'] == true) {
          _user = _extractUserFromResult(result);
          _isLoggedIn = true;
          // Admin endpoint'leri buzza-admin/v1'de — oraya set et
          final adminUrl = '$cleanUrl/wp-json/buzza-admin/v1';
          _api.setBaseUrl(adminUrl);
          await prefs.setString('api_base_url', adminUrl);
          notifyListeners();
          return true;
        }
      } catch (_) {}
    }

    // Token geçersiz — kullanıcı manuel giriş yapsın
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
