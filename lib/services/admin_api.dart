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
  String get baseUrl => _baseUrl;
  bool get hasToken => _token.isNotEmpty;

  void setToken(String token) {
    _token = token;
  }

  void setBaseUrl(String url) {
    var clean = url.trim();
    clean = clean.replaceAll(RegExp(r'/wp-admin.*$', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'/wp-json.*$', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'/+$'), '');
    _baseUrl = '$clean/wp-json/buzza-admin/v1';
  }

  void clearSession() {
    _token = '';
  }

  String _siteRootUrl() {
    final marker = '/wp-json/';
    final lower = _baseUrl.toLowerCase();
    final index = lower.indexOf(marker);
    if (index >= 0) {
      return _baseUrl.substring(0, index).replaceAll(RegExp(r'/+$'), '');
    }
    return _baseUrl.replaceAll(RegExp(r'/+$'), '');
  }

  String _restNamespacePath() {
    final marker = '/wp-json/';
    final lower = _baseUrl.toLowerCase();
    final index = lower.indexOf(marker);
    if (index >= 0) {
      return _baseUrl
          .substring(index + marker.length)
          .replaceAll(RegExp(r'^/+'), '')
          .replaceAll(RegExp(r'/+$'), '');
    }
    return 'buzza-admin/v1';
  }

  List<Uri> _buildCandidateUris(String endpoint, {bool bustCache = false}) {
    final normalizedEndpoint =
        endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final primary = Uri.parse('$_baseUrl$normalizedEndpoint');
    final primaryQuery = Map<String, String>.from(primary.queryParameters);
    if (bustCache) {
      primaryQuery['_ts'] = DateTime.now().millisecondsSinceEpoch.toString();
    }

    final siteUri = Uri.parse(_siteRootUrl());
    final secondaryQuery = Map<String, String>.from(siteUri.queryParameters);
    secondaryQuery['rest_route'] =
        '/${_restNamespacePath()}$normalizedEndpoint';
    if (bustCache) {
      secondaryQuery['_ts'] = DateTime.now().millisecondsSinceEpoch.toString();
    }

    return <Uri>[
      primary.replace(
          queryParameters: primaryQuery.isEmpty ? null : primaryQuery),
      siteUri.replace(
        path: siteUri.path.isEmpty ? '/' : siteUri.path,
        queryParameters: secondaryQuery,
      ),
    ];
  }

  Map<String, String> _jsonHeaders() {
    final siteUri = Uri.parse(_siteRootUrl());
    final origin = '${siteUri.scheme}://${siteUri.authority}';
    return <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
      'Origin': origin,
      'Referer': '$origin/',
      if (_token.isNotEmpty) 'X-Buzza-Token': _token,
      if (_token.isNotEmpty) 'X-Buzza-Auth': _token,
      if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
    };
  }

  Map<String, String> _formHeaders() {
    final siteUri = Uri.parse(_siteRootUrl());
    final origin = '${siteUri.scheme}://${siteUri.authority}';
    return <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
      'Origin': origin,
      'Referer': '$origin/',
      if (_token.isNotEmpty) 'X-Buzza-Token': _token,
      if (_token.isNotEmpty) 'X-Buzza-Auth': _token,
      if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
    };
  }

  Future<Map<String, dynamic>> _request(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    ApiException? lastError;

    for (final uri
        in _buildCandidateUris(endpoint, bustCache: method == 'GET')) {
      late http.Response response;
      switch (method) {
        case 'POST':
          response = await http
              .post(uri,
                  headers: _jsonHeaders(),
                  body: body != null ? json.encode(body) : null)
              .timeout(const Duration(seconds: 20));
          break;
        default:
          response = await http
              .get(uri, headers: _jsonHeaders())
              .timeout(const Duration(seconds: 20));
      }

      final respBody = utf8.decode(response.bodyBytes).trim();
      if (respBody.isEmpty) {
        lastError = ApiException('Sunucudan yanıt alınamadı.');
        continue;
      }
      if (respBody.startsWith('<')) {
        final normalized = _normalizeErrorText(respBody);
        lastError = ApiException(normalized);
        if (_looksLikeCloudflareBlock(normalized.toLowerCase())) {
          continue;
        }
        throw lastError;
      }

      dynamic decoded;
      try {
        decoded = json.decode(respBody);
      } on FormatException {
        final normalized = _normalizeErrorText(respBody);
        lastError = ApiException(normalized);
        if (_looksLikeCloudflareBlock(normalized.toLowerCase())) {
          continue;
        }
        throw lastError;
      }

      if (decoded is Map<String, dynamic> && _looksLikeRouteError(decoded)) {
        throw ApiException(_extractErrorMessage(decoded));
      }

      if (response.statusCode == 401) {
        throw AuthExpiredException('Oturum süresi doldu');
      }

      if (response.statusCode >= 400) {
        if (decoded is Map<String, dynamic>) {
          throw ApiException(_extractErrorMessage(decoded));
        }
        throw ApiException('HTTP ${response.statusCode}');
      }

      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }

    throw lastError ?? ApiException('Sunucudan yanıt alınamadı.');
  }

  Future<Map<String, dynamic>> _requestWithFallback(
    List<String> endpoints, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    ApiException? lastRouteError;
    for (final endpoint in endpoints) {
      try {
        return await _request(endpoint, method: method, body: body);
      } on ApiException catch (error) {
        if (_isMissingRoute(error)) {
          lastRouteError = error;
          continue;
        }
        rethrow;
      }
    }
    throw lastRouteError ??
        ApiException('Talep edilen endpoint sunucuda bulunamadı.');
  }

  Future<Map<String, dynamic>> _requestWithTrackedFallback(
    List<String> endpoints, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    ApiException? lastRouteError;
    for (final endpoint in endpoints) {
      try {
        final data = await _request(endpoint, method: method, body: body);
        return <String, dynamic>{...data, '_resolved_endpoint': endpoint};
      } on ApiException catch (error) {
        if (_isMissingRoute(error)) {
          lastRouteError = error;
          continue;
        }
        rethrow;
      }
    }
    throw lastRouteError ??
        ApiException('Talep edilen endpoint sunucuda bulunamadi.');
  }

  String _stripHtml(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&nbsp;', ' ');
  }

  bool _looksLikeWpCriticalError(String valueLower) {
    return valueLower.contains('sitenizde ciddi bir sorun') ||
        valueLower.contains('there has been a critical error') ||
        valueLower.contains('wordpress sorunlarını gidermek') ||
        valueLower.contains('wordpress sorunlarini gidermek') ||
        valueLower.contains('troubleshooting');
  }

  bool _looksLikeCloudflareBlock(String valueLower) {
    return valueLower.contains('cdn-cgi/challenge-platform') ||
        valueLower.contains('cloudflare') ||
        valueLower.contains('attention required') ||
        valueLower.contains('cf-browser-verification') ||
        (valueLower.contains('401 unauthorized') &&
            valueLower.contains('document.createelement'));
  }

  String _normalizeErrorText(String raw) {
    final cleaned = _decodeHtmlEntities(_stripHtml(raw)).trim();
    if (cleaned.isEmpty) {
      return 'Beklenmeyen sunucu hatası oluştu.';
    }
    final lower = cleaned.toLowerCase();
    if (_looksLikeCloudflareBlock(lower)) {
      return 'Site güvenlik duvarı isteği engelledi. Cloudflare veya WAF ayarlarında /wp-json ve /wp-admin/admin-ajax.php yollarına izin verilmelidir.';
    }
    if (_looksLikeWpCriticalError(lower)) {
      return 'WordPress tarafında kritik bir hata oluştu. Lütfen site yöneticiniz eklenti ve PHP hata kayıtlarını kontrol etsin.';
    }
    return cleaned;
  }

  String _extractErrorMessage(Map<String, dynamic> data) {
    final nested = _asMap(data['data']);
    final raw =
        '${data['error'] ?? data['message'] ?? nested['error'] ?? nested['message'] ?? data['code'] ?? nested['code'] ?? ''}'
            .trim();
    if (raw.isNotEmpty) return _normalizeErrorText(raw);
    return 'Bilinmeyen API hatası';
  }

  bool _looksLikeRouteError(Map<String, dynamic> data) {
    final nested = _asMap(data['data']);
    final code = '${data['code'] ?? nested['code'] ?? ''}'.toLowerCase();
    final message = _extractErrorMessage(data).toLowerCase();
    return code.contains('rest_no_route') ||
        code.contains('rest_invalid_handler') ||
        message.contains('no route') ||
        message.contains('route handler') ||
        message.contains('eşleşen yol bulunamadı') ||
        message.contains('eslesen yol bulunamadi') ||
        message.contains('yol işleyicisi geçersiz') ||
        message.contains('yol isleyicisi gecersiz') ||
        message.contains('undefined method') ||
        message.contains('not found');
  }

  bool _isMissingRoute(ApiException error) {
    final message = error.message.toLowerCase();
    return message.contains('no route') ||
        message.contains('rest_no_route') ||
        message.contains('rest_invalid_handler') ||
        message.contains('yol işleyicisi geçersiz') ||
        message.contains('yol isleyicisi gecersiz') ||
        message.contains('route handler') ||
        message.contains('eşleşen yol bulunamadı') ||
        message.contains('eslesen yol bulunamadi') ||
        message.contains('undefined method') ||
        message.contains('not found');
  }

  bool _isRetryableLoginError(ApiException error) {
    final message = error.message.toLowerCase();
    return _isMissingRoute(error) ||
        message.contains('kritik bir hata') ||
        message.contains('critical error') ||
        message.contains('api bulunamadı') ||
        message.contains('api bulunamadi') ||
        message.contains('json değil') ||
        message.contains('json degil') ||
        message.contains('geçersiz yanıt') ||
        message.contains('gecersiz yanit') ||
        message.contains('endpointi bulunamadı') ||
        message.contains('endpointi bulunamadi');
  }

  String _siteBaseUrl() {
    return _siteRootUrl();
  }

  String _extractTokenFromHeaders(Map<String, String> headers) {
    final direct =
        '${headers['x-buzza-token'] ?? headers['x-buzza-auth'] ?? headers['x-wp-token'] ?? ''}'
            .trim();
    if (direct.isNotEmpty) return direct;

    final authHeader = '${headers['authorization'] ?? ''}'.trim();
    if (authHeader.toLowerCase().startsWith('bearer ')) {
      return authHeader.substring(7).trim();
    }
    return '';
  }

  String _extractTokenFromLoginMap(Map<String, dynamic> data) {
    var token =
        '${data['token'] ?? data['access_token'] ?? data['jwt'] ?? data['jwt_token'] ?? data['auth_token'] ?? data['session_token'] ?? ''}'
            .trim();

    if (token.isEmpty && data['data'] is String) {
      token = '${data['data']}'.trim();
    }

    if (token.isEmpty && data['result'] is Map) {
      final result = Map<String, dynamic>.from(data['result'] as Map);
      token =
          '${result['token'] ?? result['access_token'] ?? result['jwt'] ?? result['jwt_token'] ?? result['auth_token'] ?? ''}'
              .trim();
    }

    if (token.isEmpty && data['data'] is Map) {
      final nested = Map<String, dynamic>.from(data['data'] as Map);
      token =
          '${nested['token'] ?? nested['access_token'] ?? nested['jwt'] ?? nested['jwt_token'] ?? nested['auth_token'] ?? nested['session_token'] ?? nested['accessToken'] ?? nested['bearer'] ?? ''}'
              .trim();
      if (token.isEmpty && nested['data'] is Map) {
        final deep = Map<String, dynamic>.from(nested['data'] as Map);
        token =
            '${deep['token'] ?? deep['access_token'] ?? deep['jwt'] ?? deep['jwt_token'] ?? deep['auth_token'] ?? deep['session_token'] ?? ''}'
                .trim();
      }
    }

    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }

    return token;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? fallback;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '$value'.trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'on' ||
        text == 'active';
  }

  int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  bool? _asNullableBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '$value'.trim().toLowerCase();
    if (text.isEmpty) return null;
    if (text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'ok' ||
        text == 'success') {
      return true;
    }
    if (text == '0' ||
        text == 'false' ||
        text == 'no' ||
        text == 'fail' ||
        text == 'error') {
      return false;
    }
    return null;
  }

  int? _readSyncMetric(List<Map<String, dynamic>> scopes, List<String> keys) {
    for (final scope in scopes) {
      for (final key in keys) {
        final value = _asNullableInt(scope[key]);
        if (value != null) return value;
      }
    }
    return null;
  }

  bool? _readSyncSuccess(List<Map<String, dynamic>> scopes) {
    for (final scope in scopes) {
      final value = _asNullableBool(
          scope['success'] ?? scope['ok'] ?? scope['status_ok']);
      if (value != null) return value;
    }
    return null;
  }

  String _readSyncMessage(List<Map<String, dynamic>> scopes) {
    for (final scope in scopes) {
      final text = _pickString(
          scope, ['message', 'detail', 'status_text', 'result', 'note']);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Map<String, dynamic> _normalizeSyncResponse(
    Map<String, dynamic> raw, {
    required String type,
  }) {
    final data = _asMap(raw['data']);
    final result = _asMap(raw['result']);
    final summary = _asMap(raw['summary']);
    final stats = _asMap(raw['stats']);
    final metrics = _asMap(raw['metrics']);

    final scopes = <Map<String, dynamic>>[
      raw,
      data,
      result,
      summary,
      stats,
      metrics,
    ];

    final total = _readSyncMetric(
        scopes, ['total', 'total_count', 'records_total', 'services_total']);
    final matched = _readSyncMetric(scopes, [
      'matched',
      'matched_count',
      'processed',
      'processed_count',
      'checked',
      'scanned',
      'found',
    ]);
    final updated = _readSyncMetric(scopes, [
      'updated',
      'updated_count',
      'synced',
      'synced_count',
      'inserted',
      'created',
      'saved',
      'changed',
      'written',
    ]);
    final skipped = _readSyncMetric(scopes, [
      'skipped',
      'skipped_count',
      'unchanged',
      'no_change',
      'already_current',
    ]);
    final errors = _readSyncMetric(
        scopes, ['errors', 'error_count', 'failed', 'failed_count']);
    final success = _readSyncSuccess(scopes);
    final message = _readSyncMessage(scopes);
    final endpoint = '${raw['_resolved_endpoint'] ?? ''}'.trim();

    return <String, dynamic>{
      ...raw,
      'sync_type': type,
      'resolved_endpoint': endpoint,
      'sync_summary': <String, dynamic>{
        if (total != null) 'total': total,
        if (matched != null) 'matched': matched,
        if (updated != null) 'updated': updated,
        if (skipped != null) 'skipped': skipped,
        if (errors != null) 'errors': errors,
        if (success != null) 'success': success,
        if (message.isNotEmpty) 'message': message,
        if (endpoint.isNotEmpty) 'endpoint': endpoint,
      },
    };
  }

  Map<String, dynamic> _normalizeNotification(dynamic rawValue) {
    final raw = _asMap(rawValue);
    final status = '${raw['status'] ?? 'created'}'.toLowerCase();
    return <String, dynamic>{
      ...raw,
      'id': _asInt(raw['id']),
      'title': raw['title'] ?? raw['subject'] ?? '-',
      'message': raw['message'] ?? raw['body'] ?? '',
      'status': status,
      'is_read':
          status == 'read' || status == 'seen' ? true : _asBool(raw['is_read']),
      'sent_at': raw['sent_at'] ?? raw['created_at'] ?? raw['date'] ?? '',
      'action': raw['action'] ?? raw['link_url'] ?? raw['cta_url'] ?? '',
      'link_url': raw['link_url'] ?? raw['cta_url'] ?? '',
      'icon': raw['icon'] ?? raw['type'] ?? 'notifications',
    };
  }

  Map<String, dynamic> _normalizeCampaign(dynamic rawValue) {
    final raw = _asMap(rawValue);
    final cover = raw['cover_image'] ?? raw['media_url'] ?? raw['image'] ?? '';
    final icon = raw['icon'] ?? raw['icon_url'] ?? raw['icon_image'] ?? '';
    return <String, dynamic>{
      ...raw,
      'id': _asInt(raw['id']),
      'title': raw['title'] ?? raw['name'] ?? 'Kampanya',
      'description': raw['description'] ?? raw['message'] ?? '',
      'details': raw['details'] ?? raw['body'] ?? raw['content'] ?? '',
      'is_active': _asBool(raw['is_active'] ?? raw['active']),
      'start_at': raw['start_at'] ?? raw['start_date'] ?? '',
      'end_at': raw['end_at'] ?? raw['end_date'] ?? '',
      'cta_label': raw['cta_label'] ?? '',
      'cta_url': raw['cta_url'] ?? raw['link_url'] ?? '',
      'service_id': _asInt(raw['service_id']),
      'service_name': raw['service_name'] ?? raw['service'] ?? '',
      'cover_image': '$cover',
      'image': raw['image'] ?? cover ?? '',
      'media_url': raw['media_url'] ?? cover ?? '',
      'icon': '$icon',
      'icon_url': raw['icon_url'] ?? icon ?? '',
    };
  }

  Map<String, dynamic> _normalizeCampaignPayload(Map<String, dynamic> input) {
    final payload = Map<String, dynamic>.from(input);
    final cover =
        '${payload['cover_image'] ?? payload['media_url'] ?? payload['image'] ?? ''}'
            .trim();
    final icon =
        '${payload['icon'] ?? payload['icon_url'] ?? payload['icon_image'] ?? ''}'
            .trim();
    final serviceName =
        '${payload['service_name'] ?? payload['service'] ?? ''}'.trim();

    if (cover.isNotEmpty) {
      payload['cover_image'] = cover;
      payload['media_url'] = cover;
      payload['image'] = cover;
    }
    if (icon.isNotEmpty) {
      payload['icon'] = icon;
      payload['icon_url'] = icon;
    }
    if (serviceName.isNotEmpty) {
      payload['service_name'] = serviceName;
      payload['service'] = serviceName;
    }

    return payload;
  }

  Future<Map<String, dynamic>> _loginWithUri(
    Uri uri,
    String username,
    String password,
  ) async {
    final formBody = <String, String>{
      'username': username,
      'user_login': username,
      'email': username,
      'login': username,
      'log': username,
      'password': password,
      'pass': password,
      'pwd': password,
    };

    final attempts = <Map<String, dynamic>>[
      <String, dynamic>{
        'headers': _jsonHeaders(),
        'body': json.encode(formBody),
      },
      <String, dynamic>{
        'headers': _formHeaders(),
        'body': formBody,
      },
    ];

    ApiException? lastError;
    for (final attempt in attempts) {
      try {
        final headers = Map<String, String>.from(attempt['headers'] as Map);
        final body = attempt['body'];
        final response = await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 20));

        final respBody = utf8.decode(response.bodyBytes).trim();
        if (respBody.isEmpty) {
          throw ApiException('Sunucudan yanıt alınamadı.');
        }
        if (respBody.startsWith('<')) {
          throw ApiException(_normalizeErrorText(respBody));
        }

        dynamic data;
        try {
          data = json.decode(respBody);
        } on FormatException {
          throw ApiException(_normalizeErrorText(respBody));
        }

        if (data is Map<String, dynamic> && _looksLikeRouteError(data)) {
          throw ApiException(_extractErrorMessage(data));
        }

        if (response.statusCode >= 400) {
          if (data is Map<String, dynamic>) {
            throw ApiException(_extractErrorMessage(data));
          }
          throw ApiException('Giriş başarısız');
        }

        if (data is Map<String, dynamic>) {
          var token = _extractTokenFromLoginMap(data);
          if (token.isEmpty) {
            token = _extractTokenFromHeaders(response.headers);
          }
          if (token.isEmpty) {
            throw ApiException(
                'Giriş başarılı görünüyor ancak oturum anahtarı alınamadı.');
          }
          _token = token;
          return data;
        }

        if (data is String || data is num) {
          final tokenFromBody = '$data'.trim();
          if (tokenFromBody.isNotEmpty) {
            _token = tokenFromBody;
            return <String, dynamic>{'token': tokenFromBody};
          }
        }

        throw ApiException('Sunucu geçersiz yanıt döndürdü');
      } on ApiException catch (error) {
        lastError = error;
        if (!_isRetryableLoginError(error)) rethrow;
      }
    }

    throw lastError ?? ApiException('Giriş başarısız');
  }

  Future<Map<String, dynamic>> _loginWithEndpoint(
    String endpoint,
    String username,
    String password,
  ) async {
    ApiException? lastError;
    for (final uri in _buildCandidateUris(endpoint)) {
      try {
        return await _loginWithUri(uri, username, password);
      } on ApiException catch (error) {
        lastError = error;
        if (_looksLikeCloudflareBlock(error.message.toLowerCase()) ||
            _isRetryableLoginError(error)) {
          continue;
        }
        rethrow;
      }
    }
    throw lastError ?? ApiException('Giriş başarısız');
  }

  Future<Map<String, dynamic>> _loginWithAbsolutePath(
    String path,
    String username,
    String password,
  ) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('${_siteBaseUrl()}$normalized');
    return _loginWithUri(uri, username, password);
  }

  Future<Map<String, dynamic>> _loginViaAdminAjax(
    String username,
    String password,
  ) async {
    final ajaxUri = Uri.parse('${_siteBaseUrl()}/wp-admin/admin-ajax.php');
    ApiException? lastError;

    for (final action in const [
      'buzza_admin_login',
      'buzza_api_login',
      'buzza_login',
      'buzza_mobile_login',
    ]) {
      try {
        final response = await http.post(
          ajaxUri,
          headers: _formHeaders(),
          body: {
            'action': action,
            'username': username,
            'user_login': username,
            'email': username,
            'password': password,
            'pass': password,
          },
        ).timeout(const Duration(seconds: 20));

        final respBody = utf8.decode(response.bodyBytes).trim();
        if (respBody.isEmpty) {
          lastError = ApiException('Sunucudan yanıt alınamadı.');
          continue;
        }
        if (respBody.startsWith('<')) {
          lastError = ApiException(_normalizeErrorText(respBody));
          continue;
        }

        dynamic decoded;
        try {
          decoded = json.decode(respBody);
        } on FormatException {
          lastError = ApiException(_normalizeErrorText(respBody));
          continue;
        }

        if (decoded is! Map) {
          continue;
        }

        final data = Map<String, dynamic>.from(decoded as Map);
        if (response.statusCode >= 400 || data['success'] == false) {
          lastError = ApiException(_extractErrorMessage(data));
          continue;
        }

        var token = _extractTokenFromLoginMap(data);
        if (token.isEmpty) {
          token = _extractTokenFromHeaders(response.headers);
        }
        if (token.isEmpty) {
          lastError = ApiException(
              'Giriş başarılı görünüyor ancak oturum anahtarı alınamadı.');
          continue;
        }

        _token = token;
        return data;
      } on ApiException catch (error) {
        lastError = error;
      } catch (error) {
        lastError = ApiException('Bağlantı hatası: $error');
      }
    }

    throw lastError ??
        ApiException(
          'Giriş endpointi bulunamadı. Eklentinin aktif olduğundan ve URL\'nin doğru olduğundan emin olun.',
        );
  }

  Future<Map<String, dynamic>> login(
      String url, String username, String password) async {
    setBaseUrl(url);
    ApiException? lastError;
    for (final endpoint in const [
      '/auth/login',
      '/login',
      '/auth/token',
      '/token'
    ]) {
      try {
        return await _loginWithEndpoint(endpoint, username, password);
      } on ApiException catch (error) {
        lastError = error;
        if (_isRetryableLoginError(error)) {
          continue;
        }
        rethrow;
      }
    }

    for (final path in const [
      '/wp-json/buzza-admin/v1/auth/login',
      '/wp-json/buzza-admin/v1/login',
      '/wp-json/buzza/admin/v1/auth/login',
      '/wp-json/buzza/admin/v1/login',
      '/wp-json/buzza/v1/auth/login',
      '/wp-json/buzza/v1/login',
      '/wp-json/jwt-auth/v1/token',
      '/wp-json/simple-jwt-login/v1/auth',
    ]) {
      try {
        return await _loginWithAbsolutePath(path, username, password);
      } on ApiException catch (error) {
        lastError = error;
        if (_isRetryableLoginError(error)) {
          continue;
        }
        rethrow;
      }
    }

    try {
      return await _loginViaAdminAjax(username, password);
    } on ApiException catch (ajaxError) {
      throw ajaxError;
    }
  }

  Future<Map<String, dynamic>> verify() async {
    final data = await _request('/auth/verify');
    if (data['valid'] == true) return data;
    if (data['ok'] == true || data['success'] == true) {
      return <String, dynamic>{...data, 'valid': true};
    }
    return data;
  }

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final data = await _requestWithFallback([
        '/dashboard',
        '/dashboard/summary',
        '/dashboard/stats',
        '/stats',
        '/system/stats',
        '/summary',
        '/overview',
      ]);
      return _normalizeDashboard(data);
    } on ApiException catch (error) {
      if (!_isMissingRoute(error)) rethrow;
      return _buildDashboardFromAvailableEndpoints();
    }
  }

  Map<String, dynamic> _normalizeDashboard(Map<String, dynamic> data) {
    final payload = _asMap(data['data']);
    final stats = _asMap(data['stats']);
    final resolvedStats = stats.isNotEmpty
        ? stats
        : _asMap(payload['stats']).isNotEmpty
            ? _asMap(payload['stats'])
            : _asMap(payload['summary']).isNotEmpty
                ? _asMap(payload['summary'])
                : payload;

    final recentOrdersRaw = data['recent_orders'] ??
        data['orders'] ??
        payload['recent_orders'] ??
        payload['orders'];
    final revenueRaw =
        data['revenue_7d'] ?? payload['revenue_7d'] ?? payload['revenue'];

    return <String, dynamic>{
      ...data,
      'stats': resolvedStats,
      'recent_orders': _asList(recentOrdersRaw).map(_asMap).toList(),
      'revenue_7d': _asList(revenueRaw).map(_asMap).toList(),
    };
  }

  Future<Map<String, dynamic>> _buildDashboardFromAvailableEndpoints() async {
    Map<String, dynamic> ordersData = <String, dynamic>{};
    Map<String, dynamic> servicesData = <String, dynamic>{};
    Map<String, dynamic> usersData = <String, dynamic>{};
    Map<String, dynamic> paymentsData = <String, dynamic>{};

    try {
      ordersData = await getOrders(page: 1);
    } catch (_) {}
    try {
      servicesData = await getServices(page: 1);
    } catch (_) {}
    try {
      usersData = await getUsers(page: 1);
    } catch (_) {}
    try {
      paymentsData = await getPayments(page: 1, status: 'pending');
    } catch (_) {}

    final orderItems = _asList(ordersData['items']).map(_asMap).toList();
    final pendingOrders = orderItems.where((item) {
      final status = '${item['status'] ?? ''}'.toLowerCase();
      return status == 'pending' ||
          status == 'processing' ||
          status == 'in_progress';
    }).length;

    final pendingPayments = _asInt(
      paymentsData['total'],
      fallback: _asList(paymentsData['items']).length,
    );

    return <String, dynamic>{
      'stats': <String, dynamic>{
        'total_orders':
            _asInt(ordersData['total'], fallback: orderItems.length),
        'today_orders': 0,
        'month_revenue': 0,
        'today_revenue': 0,
        'total_services': _asInt(
          servicesData['total'],
          fallback: _asList(servicesData['items']).length,
        ),
        'total_categories': _asList(servicesData['categories']).length,
        'total_users': _asInt(
          usersData['total'],
          fallback: _asList(usersData['items']).length,
        ),
        'pending_orders': pendingOrders,
        'pending_payments': pendingPayments,
      },
      'recent_orders': orderItems.take(10).toList(),
      'revenue_7d': const <Map<String, dynamic>>[],
    };
  }

  Future<Map<String, dynamic>> getServices({
    int page = 1,
    String search = '',
    String category = '',
    String active = '',
  }) async {
    var query = '?page=$page';
    if (search.isNotEmpty) query += '&search=${Uri.encodeComponent(search)}';
    if (category.isNotEmpty)
      query += '&category=${Uri.encodeComponent(category)}';
    if (active.isNotEmpty) query += '&active=${Uri.encodeComponent(active)}';

    final data = await _requestWithFallback([
      '/services$query',
      '/service-list$query',
      '/buzza-services$query',
    ]);

    final payload = _asMap(data['data']);
    final rawItems = data['items'] ??
        data['services'] ??
        payload['items'] ??
        payload['services'];
    final rawCategories = data['categories'] ?? payload['categories'];

    final items = _asList(rawItems).map((item) {
      final map = _asMap(item);
      map['is_active'] = map['is_active'] ?? map['active'];
      return map;
    }).toList();

    return <String, dynamic>{
      ...data,
      'items': items,
      'categories': _asList(rawCategories).map(_asMap).toList(),
      'total': _asInt(data['total'],
          fallback: _asInt(payload['total'], fallback: items.length)),
      'pages': _asInt(data['pages'],
          fallback: _asInt(payload['pages'], fallback: 1)),
      'page': _asInt(data['page'],
          fallback: _asInt(payload['page'], fallback: page)),
    };
  }

  Future<Map<String, dynamic>> updateService(
          int id, Map<String, dynamic> data) =>
      _requestWithFallback([
        '/services/$id',
        '/services/$id/update',
      ], method: 'POST', body: data);

  Future<Map<String, dynamic>> syncServices() async {
    final data = await _requestWithTrackedFallback([
      '/services/sync',
      '/services/sync-services',
      '/services/sync-all',
    ], method: 'POST');
    return _normalizeSyncResponse(data, type: 'services');
  }

  Future<Map<String, dynamic>> reorderServices(List<int> ids) =>
      _request('/services/reorder', method: 'POST', body: {'ids': ids});

  Future<Map<String, dynamic>> syncCategories() async {
    final data = await _requestWithTrackedFallback([
      '/services/sync-categories',
      '/categories/sync',
      '/service-categories/sync',
      '/services/categories/sync',
    ], method: 'POST');
    return _normalizeSyncResponse(data, type: 'categories');
  }

  Future<Map<String, dynamic>> syncDescriptions() async {
    final data = await _requestWithTrackedFallback([
      '/services/sync-descriptions',
      '/services/sync-description',
      '/services/descriptions/sync',
      '/descriptions/sync',
      '/medyabayim/sync-descriptions',
      '/medyabayim/sync',
      '/scraper/sync-descriptions',
      '/services/sync-all',
    ], method: 'POST');
    return _normalizeSyncResponse(data, type: 'descriptions');
  }

  Future<Map<String, dynamic>> syncAll() async {
    final data = await _requestWithTrackedFallback([
      '/services/sync-all',
      '/services/sync',
      '/sync/all',
    ], method: 'POST');
    return _normalizeSyncResponse(data, type: 'all');
  }

  Future<Map<String, dynamic>> deleteAllServices() =>
      _request('/services/delete-all', method: 'POST');

  Future<Map<String, dynamic>> resetAll() =>
      _request('/system/reset', method: 'POST');

  Future<Map<String, dynamic>> getCategories() async {
    final data = await _requestWithFallback([
      '/categories',
      '/service-categories',
    ]);

    final payload = _asMap(data['data']);
    final rawItems = data['items'] ??
        data['categories'] ??
        payload['items'] ??
        payload['categories'];
    final items = _asList(rawItems).map((item) {
      final map = _asMap(item);
      map['is_active'] = map['is_active'] ?? map['active'];
      map['active'] = map['is_active'] ?? map['active'];
      return map;
    }).toList();

    return <String, dynamic>{...data, 'items': items};
  }

  Future<Map<String, dynamic>> updateCategory(
          int id, Map<String, dynamic> data) =>
      _requestWithFallback([
        '/categories/$id',
        '/service-categories/$id',
      ], method: 'POST', body: data);

  Future<Map<String, dynamic>> deleteEmptyCategories() => _requestWithFallback([
        '/categories/delete-empty',
        '/categories/cleanup-empty',
      ], method: 'POST');

  Future<Map<String, dynamic>> reorderCategories(List<int> ids) =>
      _requestWithFallback(
          [
            '/categories/reorder',
            '/service-categories/reorder',
          ],
          method: 'POST',
          body: {'ids': ids});

  Future<Map<String, dynamic>> getOrders({
    int page = 1,
    String status = '',
    String search = '',
  }) {
    var query = '?page=$page';
    if (status.isNotEmpty) query += '&status=${Uri.encodeComponent(status)}';
    if (search.isNotEmpty) query += '&search=${Uri.encodeComponent(search)}';
    return _request('/orders$query');
  }

  Future<Map<String, dynamic>> updateOrderStatus(int id, String status) =>
      _request('/orders/$id/status', method: 'POST', body: {'status': status});

  Future<Map<String, dynamic>> getOrderDetail(int id) =>
      _request('/orders/$id');

  Future<Map<String, dynamic>> cancelOrder(int id) =>
      _request('/orders/$id/cancel', method: 'POST');

  Future<Map<String, dynamic>> getUsers({int page = 1, String search = ''}) {
    var query = '?page=$page';
    if (search.isNotEmpty) query += '&search=${Uri.encodeComponent(search)}';
    return _request('/users$query');
  }

  Future<Map<String, dynamic>> updateBalance(
    int userId,
    double amount,
    String type,
    String description,
  ) =>
      _request(
        '/users/$userId/balance',
        method: 'POST',
        body: {'amount': amount, 'type': type, 'description': description},
      );

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

  Future<Map<String, dynamic>> getPayments({int page = 1, String status = ''}) {
    var query = '?page=$page';
    if (status.isNotEmpty) query += '&status=${Uri.encodeComponent(status)}';
    return _request('/payments$query');
  }

  Future<Map<String, dynamic>> paymentAction(int id, String actionType) =>
      _request('/payments/$id/action',
          method: 'POST', body: {'action_type': actionType});

  Future<Map<String, dynamic>> getTickets({int page = 1}) =>
      _request('/tickets?page=$page');

  Future<Map<String, dynamic>> replyTicket(int id, String message) =>
      _request('/tickets/$id/reply',
          method: 'POST', body: {'message': message});

  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    String status = '',
    String audience = 'all',
  }) async {
    final queryItems = <String, String>{'page': '$page'};
    if (status.isNotEmpty) queryItems['status'] = status;
    if (audience.isNotEmpty && audience != 'all')
      queryItems['audience'] = audience;
    final query = queryItems.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');

    try {
      final data = await _requestWithFallback([
        '/notifications?$query',
        '/push-notifications?$query',
        '/notifications/list?$query',
      ]);
      final payload = _asMap(data['data']);
      final rawItems = data['items'] ??
          data['notifications'] ??
          payload['items'] ??
          payload['notifications'];
      return <String, dynamic>{
        ...data,
        'items': _asList(rawItems).map(_normalizeNotification).toList(),
        'total': _asInt(data['total'], fallback: _asInt(payload['total'])),
        'page': _asInt(data['page'], fallback: page),
        'pages': _asInt(data['pages'], fallback: 1),
        'supported': true,
      };
    } on ApiException catch (error) {
      if (_isMissingRoute(error)) {
        return <String, dynamic>{
          'items': const <Map<String, dynamic>>[],
          'total': 0,
          'page': page,
          'pages': 1,
          'supported': false,
        };
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendNotification(
      Map<String, dynamic> data) async {
    try {
      return await _requestWithFallback([
        '/notifications/send',
        '/push-notifications/send',
        '/notifications',
      ], method: 'POST', body: data);
    } on ApiException catch (error) {
      if (_isMissingRoute(error)) {
        throw ApiException('Bildirim servisi bu sunucuda bulunmuyor');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCampaigns(
      {int page = 1, bool activeOnly = false}) async {
    final queryItems = <String, String>{
      'page': '$page',
      if (activeOnly) 'status': 'active',
    };
    final query = queryItems.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');

    try {
      final data = await _requestWithFallback([
        '/campaigns?$query',
        '/marketing/campaigns?$query',
        '/notifications/campaigns?$query',
      ]);
      final payload = _asMap(data['data']);
      final rawItems = data['items'] ??
          data['campaigns'] ??
          payload['items'] ??
          payload['campaigns'];
      return <String, dynamic>{
        ...data,
        'items': _asList(rawItems).map(_normalizeCampaign).toList(),
        'total': _asInt(data['total'], fallback: _asInt(payload['total'])),
        'page': _asInt(data['page'], fallback: page),
        'pages': _asInt(data['pages'], fallback: 1),
        'supported': true,
      };
    } on ApiException catch (error) {
      if (_isMissingRoute(error)) {
        return <String, dynamic>{
          'items': const <Map<String, dynamic>>[],
          'total': 0,
          'page': page,
          'pages': 1,
          'supported': false,
        };
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCampaign(Map<String, dynamic> data) async {
    try {
      final payload = _normalizeCampaignPayload(data);
      return await _requestWithFallback([
        '/campaigns',
        '/marketing/campaigns',
        '/notifications/campaigns',
      ], method: 'POST', body: payload);
    } on ApiException catch (error) {
      if (_isMissingRoute(error)) {
        throw ApiException('Kampanya servisi bu sunucuda bulunmuyor');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCampaign(
      int id, Map<String, dynamic> data) async {
    try {
      final payload = _normalizeCampaignPayload(data);
      return await _requestWithFallback([
        '/campaigns/$id',
        '/marketing/campaigns/$id',
        '/notifications/campaigns/$id',
      ], method: 'POST', body: payload);
    } on ApiException catch (error) {
      if (_isMissingRoute(error)) {
        throw ApiException('Kampanya güncelleme bu sunucuda desteklenmiyor');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCronStatus() => _request('/cron');

  Future<Map<String, dynamic>> runCronJob(String job) =>
      _request('/cron/run', method: 'POST', body: {'job': job});

  Future<Map<String, dynamic>> getSecurity({int page = 1}) async {
    final data = await _request('/security?page=$page');
    final items = _asList(data['items'] ?? data['blocked'])
        .map(_normalizeSecurityItem)
        .toList();
    final events =
        _asList(data['events']).map(_normalizeSecurityLogItem).toList();

    return {
      ...data,
      'items': items,
      'events': events,
      'page': _asInt(data['page'], fallback: page),
      'pages': _asInt(data['pages'], fallback: 1),
    };
  }

  Future<Map<String, dynamic>> securityAction(String ip, String actionType) =>
      _request('/security/block',
          method: 'POST', body: {'ip': ip, 'action_type': actionType});

  Future<Map<String, dynamic>> getRateLimitSettings() async {
    try {
      final data = await _request('/security/rate-limit');
      return {
        ...data,
        'enabled': data['enabled'] ?? data['active'] ?? false,
        'max_requests':
            _asInt(data['max_requests'] ?? data['limit'], fallback: 60),
        'window_seconds':
            _asInt(data['window_seconds'] ?? data['window'], fallback: 60),
      };
    } on ApiException catch (e) {
      if (!_isMissingRouteError(e.message)) rethrow;
      return {
        'success': true,
        'enabled': false,
        'max_requests': 60,
        'window_seconds': 60,
        'message':
            'Bu yedek eklenti sürümünde rate limit endpointi bulunmuyor.',
      };
    }
  }

  Future<Map<String, dynamic>> saveRateLimitSettings(
          Map<String, dynamic> data) =>
      _request('/security/rate-limit', method: 'POST', body: data);

  Future<Map<String, dynamic>> getSecurityLogs({int page = 1}) async {
    try {
      final data = await _request('/security/logs?page=$page');
      return {
        ...data,
        'items': _asList(data['items']).map(_normalizeSecurityLogItem).toList(),
        'page': _asInt(data['page'], fallback: page),
        'pages': _asInt(data['pages'], fallback: 1),
      };
    } on ApiException catch (e) {
      if (!_isMissingRouteError(e.message)) rethrow;
      final data = await _request('/security?page=$page');
      final items =
          _asList(data['events']).map(_normalizeSecurityLogItem).toList();
      return {
        'success': true,
        'items': items,
        'page': _asInt(data['page'], fallback: page),
        'pages': _asInt(data['pages'], fallback: 1),
        'total': _asInt(data['total_events'], fallback: items.length),
      };
    }
  }

  Future<Map<String, dynamic>> getSettings() => _request('/settings');

  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> data) =>
      _request('/settings', method: 'POST', body: data);

  Future<Map<String, dynamic>> getErrorLog({int lines = 80}) async {
    final data = await _request('/errorlog?lines=$lines');
    final content = data['content']?.toString() ??
        _asList(data['lines']).map((e) => e.toString()).join('\n');
    return {
      ...data,
      'content': content,
    };
  }

  bool _isMissingRouteError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('no route was found') ||
        lower.contains('route') ||
        lower.contains('not found') ||
        lower.contains('eşleşen yol bulunamadı') ||
        lower.contains('bulunamadı');
  }

  String _pickString(Map<String, dynamic> data, List<String> keys,
      [String fallback = '']) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  Map<String, dynamic> _normalizeSecurityItem(dynamic item) {
    final data =
        item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    return {
      ...data,
      'ip': _pickString(data, ['ip', 'user_ip', 'address']),
      'reason': _pickString(data, ['reason', 'message', 'note'], 'Engellendi'),
      'type': _pickString(data, ['type', 'action', 'status'], 'blocked'),
      'date': _pickString(data, ['date', 'created_at', 'time', 'timestamp']),
    };
  }

  Map<String, dynamic> _normalizeSecurityLogItem(dynamic item) {
    final data =
        item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    return {
      ...data,
      'ip': _pickString(data, ['ip', 'user_ip', 'address']),
      'event': _pickString(data, ['event', 'action', 'type'], 'security'),
      'message': _pickString(data, ['message', 'reason', 'details', 'event']),
      'type': _pickString(data, ['type', 'level', 'action'], 'info'),
      'date': _pickString(data, ['date', 'created_at', 'time', 'timestamp']),
    };
  }
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
