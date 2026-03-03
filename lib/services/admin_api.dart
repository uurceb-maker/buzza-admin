import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

class AdminApi {
  static final AdminApi _instance = AdminApi._internal();
  factory AdminApi() => _instance;
  AdminApi._internal();

  String _token = '';
  String _baseUrl = AppConstants.apiBase;

  String get token => _token;
  bool get hasToken => _token.isNotEmpty;

  void setToken(String token) { _token = token; }
  void setBaseUrl(String url) {
    // Strip common paths users might add
    var clean = url.trim();
    clean = clean.replaceAll(RegExp(r'/wp-admin.*$', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'/wp-json.*$', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'/+$'), '');
    _baseUrl = '$clean/wp-json/buzza-admin/v1';
  }

  void clearSession() { _token = ''; }

  // ─── Core HTTP ───

  Future<Map<String, dynamic>> _request(String endpoint, {String method = 'GET', Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_token.isNotEmpty) 'X-Buzza-Token': _token,
    };

    late http.Response response;
    switch (method) {
      case 'POST':
        response = await http.post(uri, headers: headers, body: body != null ? json.encode(body) : null)
            .timeout(const Duration(seconds: 20));
        break;
      default:
        response = await http.get(uri, headers: headers)
            .timeout(const Duration(seconds: 20));
    }

    if (response.statusCode == 401) {
      throw AuthExpiredException('Oturum süresi doldu');
    }

    // Detect HTML responses (plugin not active or wrong URL)
    final respBody = response.body.trim();
    if (respBody.startsWith('<!') || respBody.startsWith('<html')) {
      throw ApiException('API bulunamadı. Eklentinin aktif olduğundan ve URL\'nin doğru olduğundan emin olun.');
    }
    try {
      final data = json.decode(respBody);
      if (response.statusCode >= 400) {
        throw ApiException(data['error'] ?? data['message'] ?? 'HTTP ${response.statusCode}');
      }
      return data is Map<String, dynamic> ? data : {'data': data};
    } on FormatException {
      throw ApiException('Sunucu geçersiz yanıt döndü (JSON değil)');
    }
  }

  // ─── Auth ───

  Future<Map<String, dynamic>> login(String url, String username, String password) async {
    setBaseUrl(url);
    final uri = Uri.parse('$_baseUrl/auth/login');
    final response = await http.post(uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    ).timeout(const Duration(seconds: 20));

    final respBody = response.body.trim();
    if (respBody.startsWith('<!') || respBody.startsWith('<html')) {
      throw ApiException('API bulunamadı. Eklentinin aktif olduğundan ve URL\'nin doğru olduğundan emin olun.');
    }
    late final dynamic data;
    try {
      data = json.decode(respBody);
    } on FormatException {
      throw ApiException('Sunucu geçersiz yanıt döndü (JSON değil)');
    }
    if (response.statusCode >= 400) {
      throw ApiException(data['error'] ?? 'Giriş başarısız');
    }
    _token = data['token'] ?? '';
    return data;
  }

  Future<Map<String, dynamic>> verify() => _request('/auth/verify');

  // ─── Dashboard ───
  Future<Map<String, dynamic>> getDashboard() => _request('/dashboard');

  // ─── Services ───
  Future<Map<String, dynamic>> getServices({int page = 1, String search = '', String category = '', String active = ''}) {
    var q = '?page=$page';
    if (search.isNotEmpty) q += '&search=${Uri.encodeComponent(search)}';
    if (category.isNotEmpty) q += '&category=$category';
    if (active.isNotEmpty) q += '&active=$active';
    return _request('/services$q');
  }

  Future<Map<String, dynamic>> updateService(int id, Map<String, dynamic> data) =>
      _request('/services/$id', method: 'POST', body: data);

  Future<Map<String, dynamic>> syncServices() =>
      _request('/services/sync', method: 'POST');

  Future<Map<String, dynamic>> reorderServices(List<int> ids) =>
      _request('/services/reorder', method: 'POST', body: {'ids': ids});

  // ─── Sync Operations ───
  Future<Map<String, dynamic>> syncCategories() =>
      _request('/services/sync-categories', method: 'POST');

  Future<Map<String, dynamic>> syncDescriptions() =>
      _request('/services/sync-descriptions', method: 'POST');

  Future<Map<String, dynamic>> syncAll() =>
      _request('/services/sync-all', method: 'POST');

  // ─── Danger Zone ───
  Future<Map<String, dynamic>> deleteAllServices() =>
      _request('/services/delete-all', method: 'POST');

  Future<Map<String, dynamic>> resetAll() =>
      _request('/system/reset', method: 'POST');

  // ─── Categories ───
  Future<Map<String, dynamic>> getCategories() => _request('/categories');

  Future<Map<String, dynamic>> updateCategory(int id, Map<String, dynamic> data) =>
      _request('/categories/$id', method: 'POST', body: data);

  Future<Map<String, dynamic>> deleteEmptyCategories() =>
      _request('/categories/delete-empty', method: 'POST');

  Future<Map<String, dynamic>> reorderCategories(List<int> ids) =>
      _request('/categories/reorder', method: 'POST', body: {'ids': ids});

  // ─── Orders ───
  Future<Map<String, dynamic>> getOrders({int page = 1, String status = '', String search = ''}) {
    var q = '?page=$page';
    if (status.isNotEmpty) q += '&status=$status';
    if (search.isNotEmpty) q += '&search=${Uri.encodeComponent(search)}';
    return _request('/orders$q');
  }

  Future<Map<String, dynamic>> updateOrderStatus(int id, String status) =>
      _request('/orders/$id/status', method: 'POST', body: {'status': status});

  Future<Map<String, dynamic>> getOrderDetail(int id) =>
      _request('/orders/$id');

  Future<Map<String, dynamic>> cancelOrder(int id) =>
      _request('/orders/$id/cancel', method: 'POST');

  // ─── Users ───
  Future<Map<String, dynamic>> getUsers({int page = 1, String search = ''}) {
    var q = '?page=$page';
    if (search.isNotEmpty) q += '&search=${Uri.encodeComponent(search)}';
    return _request('/users$q');
  }

  Future<Map<String, dynamic>> updateBalance(int userId, double amount, String type, String description) =>
      _request('/users/$userId/balance', method: 'POST', body: {'amount': amount, 'type': type, 'description': description});

  Future<Map<String, dynamic>> getUserDetail(int id) =>
      _request('/users/$id/detail');

  Future<Map<String, dynamic>> getUserSessions(int id) =>
      _request('/users/$id/sessions');

  Future<Map<String, dynamic>> getUserLogs(int id) =>
      _request('/users/$id/logs');

  Future<Map<String, dynamic>> blockUser(int id) =>
      _request('/users/$id/block', method: 'POST');

  Future<Map<String, dynamic>> resetUserPassword(int id) =>
      _request('/users/$id/reset-password', method: 'POST');

  // ─── Payments ───
  Future<Map<String, dynamic>> getPayments({int page = 1, String status = ''}) {
    var q = '?page=$page';
    if (status.isNotEmpty) q += '&status=$status';
    return _request('/payments$q');
  }

  Future<Map<String, dynamic>> paymentAction(int id, String actionType) =>
      _request('/payments/$id/action', method: 'POST', body: {'action_type': actionType});

  // ─── Tickets ───
  Future<Map<String, dynamic>> getTickets({int page = 1}) =>
      _request('/tickets?page=$page');

  Future<Map<String, dynamic>> replyTicket(int id, String message) =>
      _request('/tickets/$id/reply', method: 'POST', body: {'message': message});

  // ─── Cron ───
  Future<Map<String, dynamic>> getCronStatus() => _request('/cron');
  Future<Map<String, dynamic>> runCronJob(String job) =>
      _request('/cron/run', method: 'POST', body: {'job': job});

  // ─── Security ───
  Future<Map<String, dynamic>> getSecurity({int page = 1}) =>
      _request('/security?page=$page');

  Future<Map<String, dynamic>> securityAction(String ip, String actionType) =>
      _request('/security/block', method: 'POST', body: {'ip': ip, 'action_type': actionType});

  Future<Map<String, dynamic>> getRateLimitSettings() =>
      _request('/security/rate-limit');

  Future<Map<String, dynamic>> saveRateLimitSettings(Map<String, dynamic> data) =>
      _request('/security/rate-limit', method: 'POST', body: data);

  Future<Map<String, dynamic>> getSecurityLogs({int page = 1}) =>
      _request('/security/logs?page=$page');

  // ─── Settings ───
  Future<Map<String, dynamic>> getSettings() => _request('/settings');
  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> data) =>
      _request('/settings', method: 'POST', body: data);

  // ─── Error Log ───
  Future<Map<String, dynamic>> getErrorLog({int lines = 80}) =>
      _request('/errorlog?lines=$lines');
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class AuthExpiredException extends ApiException {
  AuthExpiredException(super.message);
}
