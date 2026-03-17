import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';

class AdminApi {
  static final AdminApi _instance = AdminApi._internal();
  static const Duration _requestTimeout = Duration(seconds: 45);

  factory AdminApi() => _instance;

  AdminApi._internal();

  String _token = '';
  String _baseUrl = AppConstants.apiBase;

  String get token => _token;
  String get baseUrl => _baseUrl;
  bool get hasToken => _token.isNotEmpty;

  String _normalizeRootUrl(String url) {
    var clean = url.trim();
    clean = clean.replaceAll(RegExp(r'/wp-admin.*$', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'/wp-json.*$', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'/+$'), '');
    return clean;
  }

  String _detectNamespaceFromRawUrl(String rawUrl) {
    final lower = rawUrl.toLowerCase();
    if (lower.contains('/wp-json/buzza/admin/v1')) return 'buzza/admin/v1';
    if (lower.contains('/wp-json/buzza-admin/v1')) return 'buzza-admin/v1';
    if (lower.contains('/wp-json/buzza-security/v1'))
      return 'buzza-security/v1';
    if (lower.contains('/wp-json/buzza/v1')) return 'buzza/v1';
    return '';
  }

  void setToken(String token) {
    _token = token;
  }

  void setBaseUrl(String url) {
    final cleanRoot = _normalizeRootUrl(url);
    final detectedNamespace = _detectNamespaceFromRawUrl(url);
    final namespace =
        detectedNamespace.isNotEmpty ? detectedNamespace : 'buzza-admin/v1';
    _baseUrl = '$cleanRoot/wp-json/$namespace';
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
      try {
        switch (method) {
          case 'POST':
            response = await http
                .post(uri,
                    headers: _jsonHeaders(),
                    body: body != null ? json.encode(body) : null)
                .timeout(_requestTimeout);
            break;
          default:
            response = await http
                .get(uri, headers: _jsonHeaders())
                .timeout(_requestTimeout);
        }
      } on TimeoutException {
        lastError = ApiException(
            'Sunucu yanit vermiyor (45 sn zaman asimi). Lutfen tekrar deneyin.');
        continue;
      } on http.ClientException catch (error) {
        lastError = ApiException('Baglanti hatasi: ${error.message}');
        continue;
      } catch (error) {
        lastError = ApiException('Baglanti hatasi: $error');
        continue;
      }

      final respBody = utf8.decode(response.bodyBytes).trim();
      if (respBody.isEmpty) {
        lastError = ApiException('Sunucudan yanit alinamadi.');
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
        throw AuthExpiredException('Oturum suresi doldu');
      }

      if (response.statusCode >= 400) {
        if (decoded is Map<String, dynamic>) {
          final extracted = _extractErrorMessage(decoded);
          if (response.statusCode == 403 &&
              _looksLikeExpiredSession(extracted)) {
            throw AuthExpiredException('Oturum suresi doldu');
          }
          throw ApiException(extracted);
        }
        throw ApiException('HTTP ${response.statusCode}');
      }

      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }

    throw lastError ?? ApiException('Sunucudan yanit alinamadi.');
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
        ApiException('Talep edilen endpoint sunucuda bulunamadi.');
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

  String _normalizeMatchText(String input) {
    return input
        .toLowerCase()
        .replaceAll('\u0131', 'i')
        .replaceAll('\u0130', 'i')
        .replaceAll('\u015f', 's')
        .replaceAll('\u015e', 's')
        .replaceAll('\u011f', 'g')
        .replaceAll('\u011e', 'g')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u00dc', 'u')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u00d6', 'o')
        .replaceAll('\u00e7', 'c')
        .replaceAll('\u00c7', 'c')
        .replaceAll(RegExp(r'[^a-z0-9/_\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _looksLikeWpCriticalError(String valueLower) {
    final text = _normalizeMatchText(valueLower);
    return text.contains('sitenizde ciddi bir sorun') ||
        text.contains('there has been a critical error') ||
        text.contains('wordpress sorunlarini gidermek') ||
        text.contains('troubleshooting');
  }

  bool _looksLikeCloudflareBlock(String valueLower) {
    final text = _normalizeMatchText(valueLower);
    return text.contains('cdn-cgi/challenge-platform') ||
        text.contains('cloudflare') ||
        text.contains('attention required') ||
        text.contains('cf-browser-verification') ||
        (text.contains('401 unauthorized') &&
            text.contains('document.createelement'));
  }

  bool _looksLikeRestAuthGate(String valueLower) {
    final text = _normalizeMatchText(valueLower);
    final hasRest = text.contains('rest api') ||
        text.contains('rest_forbidden') ||
        text.contains('yetkilendirme');
    final hasToken = text.contains('jwt token') ||
        text.contains('authorization token') ||
        text.contains('token');
    return hasRest && hasToken;
  }

  String _normalizeErrorText(String raw) {
    final cleaned = _decodeHtmlEntities(_stripHtml(raw)).trim();
    if (cleaned.isEmpty) {
      return 'Beklenmeyen sunucu hatasi olustu.';
    }
    final lower = cleaned.toLowerCase();
    if (_looksLikeCloudflareBlock(lower)) {
      return 'Site guvenlik duvari istegi engelledi. Cloudflare veya WAF ayarlarinda /wp-json ve /wp-admin/admin-ajax.php yollarina izin verilmelidir.';
    }
    if (_looksLikeWpCriticalError(lower)) {
      return 'WordPress tarafinda kritik bir hata olustu. Lutfen eklenti ve PHP hata kayitlarini kontrol edin.';
    }
    if (_looksLikeRestAuthGate(lower)) {
      return 'REST API giris istegini engelledi. Uygulama alternatif giris yolunu deniyor; sorun devam ederse login endpointi beyaz listeye alinmalidir.';
    }
    return cleaned;
  }

  String _extractErrorMessage(Map<String, dynamic> data) {
    final nested = _asMap(data['data']);
    final raw =
        '${data['error'] ?? data['message'] ?? nested['error'] ?? nested['message'] ?? data['code'] ?? nested['code'] ?? ''}'
            .trim();
    if (raw.isNotEmpty) return _normalizeErrorText(raw);
    return 'Bilinmeyen API hatasi';
  }

  bool _looksLikeRouteMessage(String message) {
    final text = _normalizeMatchText(message);
    return text.contains('rest_no_route') ||
        text.contains('rest_invalid_handler') ||
        text.contains('no route') ||
        text.contains('route handler') ||
        text.contains('eslesen yol bulunamadi') ||
        text.contains('istek yontemi ve baglantiyla eslesen yol bulunamadi') ||
        text.contains('yol isleyicisi gecersiz') ||
        text.contains('undefined method') ||
        text.contains('not found') ||
        text.contains('endpoint bulunamadi');
  }

  bool _looksLikeRouteError(Map<String, dynamic> data) {
    final nested = _asMap(data['data']);
    final code = _normalizeMatchText('${data['code'] ?? nested['code'] ?? ''}');
    if (code.contains('rest_no_route') ||
        code.contains('rest_invalid_handler')) {
      return true;
    }
    final message = _extractErrorMessage(data);
    return _looksLikeRouteMessage(message);
  }

  bool _isMissingRoute(ApiException error) {
    return _looksLikeRouteMessage(error.message);
  }

  bool _isRetryableLoginError(ApiException error) {
    final message = _normalizeMatchText(error.message);
    return _isMissingRoute(error) ||
        message.contains('rest_forbidden') ||
        _looksLikeRestAuthGate(error.message) ||
        message.contains('kritik bir hata') ||
        message.contains('critical error') ||
        message.contains('api bulunamadi') ||
        message.contains('json degil') ||
        message.contains('gecersiz yanit') ||
        message.contains('endpointi bulunamadi');
  }

  bool _looksLikeExpiredSession(String message) {
    final text = _normalizeMatchText(message);
    return text.contains('invalid token') ||
        text.contains('gecersiz token') ||
        text.contains('token expired') ||
        text.contains('jwt expired') ||
        text.contains('session expired') ||
        text.contains('oturum suresi doldu') ||
        text.contains('rest_not_logged_in') ||
        text.contains('gecersiz nonce') ||
        text.contains('nonce is invalid');
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

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
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
    final unmatched = _readSyncMetric(scopes, [
      'unmatched',
      'unmatched_count',
      'not_matched',
      'not_found',
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
        if (unmatched != null) 'unmatched': unmatched,
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
            .timeout(_requestTimeout);

        final respBody = utf8.decode(response.bodyBytes).trim();
        if (respBody.isEmpty) {
          throw ApiException('Sunucudan yanit alinamadi.');
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
          throw ApiException('Giris basarisiz');
        }

        if (data is Map<String, dynamic>) {
          var token = _extractTokenFromLoginMap(data);
          if (token.isEmpty) {
            token = _extractTokenFromHeaders(response.headers);
          }
          if (token.isEmpty) {
            throw ApiException(
                'Giris basarili gorunuyor ancak oturum anahtari alinamadi.');
          }
          _token = token;
          final resolvedNamespace = _detectNamespaceFromRawUrl(uri.toString());
          return <String, dynamic>{
            ...data,
            '_resolved_login_uri': uri.toString(),
            if (resolvedNamespace.isNotEmpty)
              '_resolved_namespace': resolvedNamespace,
          };
        }

        if (data is String || data is num) {
          final tokenFromBody = '$data'.trim();
          if (tokenFromBody.isNotEmpty) {
            _token = tokenFromBody;
            final resolvedNamespace =
                _detectNamespaceFromRawUrl(uri.toString());
            return <String, dynamic>{
              'token': tokenFromBody,
              '_resolved_login_uri': uri.toString(),
              if (resolvedNamespace.isNotEmpty)
                '_resolved_namespace': resolvedNamespace,
            };
          }
        }

        throw ApiException('Sunucu gecersiz yanit dondurdu');
      } on TimeoutException {
        lastError = ApiException(
            'Sunucu yanit vermiyor (45 sn zaman asimi). Lutfen tekrar deneyin.');
      } on http.ClientException catch (error) {
        lastError = ApiException('Baglanti hatasi: ${error.message}');
      } on ApiException catch (error) {
        lastError = error;
        if (!_isRetryableLoginError(error)) rethrow;
      } catch (error) {
        lastError = ApiException('Baglanti hatasi: $error');
      }
    }

    throw lastError ?? ApiException('Giris basarisiz');
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
    throw lastError ?? ApiException('Giris basarisiz');
  }

  bool _isExplicitlyInvalidVerification(Map<String, dynamic> data) {
    final nested = _asMap(data['data']);
    final values = <dynamic>[
      data['valid'],
      data['ok'],
      data['success'],
      data['authorized'],
      nested['valid'],
      nested['ok'],
      nested['success'],
      nested['authorized'],
    ];

    var hasExplicit = false;
    var hasTrue = false;
    for (final value in values) {
      final parsed = _asNullableBool(value);
      if (parsed == null) continue;
      hasExplicit = true;
      if (parsed) hasTrue = true;
    }

    if (hasExplicit) {
      return !hasTrue;
    }
    return false;
  }

  Future<Map<String, dynamic>?> _verifyTokenAfterLogin() async {
    if (_token.isEmpty) {
      throw ApiException(
          'Giris basarili gorunuyor ancak oturum anahtari alinamadi.');
    }

    ApiException? lastRouteError;
    for (final endpoint in const [
      '/auth/verify',
      '/verify',
      '/token/verify',
      '/auth/check',
    ]) {
      try {
        final data = await _request(endpoint);
        if (_isExplicitlyInvalidVerification(data)) {
          throw ApiException('Sunucu bu oturumu dogrulamadi.');
        }
        return data;
      } on AuthExpiredException {
        throw ApiException('Sunucu bu oturumu dogrulamadi.');
      } on ApiException catch (error) {
        final lower = error.message.toLowerCase();
        if (_isMissingRoute(error)) {
          lastRouteError = error;
          continue;
        }
        if (_looksLikeRestAuthGate(lower) || _looksLikeCloudflareBlock(lower)) {
          return null;
        }
        if (_looksLikeExpiredSession(lower)) {
          throw ApiException('Sunucu bu oturum anahtarini kabul etmedi.');
        }
        return null;
      }
    }

    if (lastRouteError != null) {
      return null;
    }
    return null;
  }

  Map<String, dynamic> _mergeLoginWithVerification(
    Map<String, dynamic> loginResult,
    Map<String, dynamic> verification,
  ) {
    final merged = Map<String, dynamic>.from(loginResult);
    final verifyData = _asMap(verification['data']);
    final verifyUser = _asMap(verification['user']);
    final verifyNestedUser = _asMap(verifyData['user']);
    final resolvedUser = verifyUser.isNotEmpty ? verifyUser : verifyNestedUser;

    if (resolvedUser.isNotEmpty) {
      if (_asMap(merged['user']).isEmpty) {
        merged['user'] = resolvedUser;
      }
      final mergedData = _asMap(merged['data']);
      if (mergedData.isNotEmpty && _asMap(mergedData['user']).isEmpty) {
        merged['data'] = <String, dynamic>{...mergedData, 'user': resolvedUser};
      }
    }

    return merged;
  }

  void _applyResolvedLoginBase(Map<String, dynamic> loginResult) {
    final namespace =
        '${loginResult['_resolved_namespace'] ?? loginResult['resolved_namespace'] ?? ''}'
            .trim();
    if (namespace.isEmpty) {
      return;
    }

    if (namespace != 'buzza-admin/v1' && namespace != 'buzza/admin/v1') {
      return;
    }

    final root = _siteRootUrl();
    _baseUrl = '$root/wp-json/$namespace';
  }

  Future<Map<String, dynamic>> _loginAndValidateSession(
    Future<Map<String, dynamic>> Function() loginAttempt,
  ) async {
    final result = await loginAttempt();
    _applyResolvedLoginBase(result);
    try {
      final verification = await _verifyTokenAfterLogin();
      if (verification == null) {
        return result;
      }
      return _mergeLoginWithVerification(result, verification);
    } on ApiException {
      _token = '';
      rethrow;
    }
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
        ).timeout(_requestTimeout);

        final respBody = utf8.decode(response.bodyBytes).trim();
        if (respBody.isEmpty) {
          lastError = ApiException('Sunucudan yanit alinamadi.');
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
              'Giris basarili gorunuyor ancak oturum anahtari alinamadi.');
          continue;
        }

        _token = token;
        return data;
      } on ApiException catch (error) {
        lastError = error;
      } catch (error) {
        lastError = ApiException('Baglanti hatasi: $error');
      }
    }

    throw lastError ??
        ApiException(
          'Giris endpointi bulunamadi. Eklentinin aktif oldugundan ve URL\'nin dogru oldugundan emin olun.',
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
        return await _loginAndValidateSession(
          () => _loginWithEndpoint(endpoint, username, password),
        );
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
        return await _loginAndValidateSession(
          () => _loginWithAbsolutePath(path, username, password),
        );
      } on ApiException catch (error) {
        lastError = error;
        if (_isRetryableLoginError(error)) {
          continue;
        }
        rethrow;
      }
    }

    try {
      return await _loginAndValidateSession(
        () => _loginViaAdminAjax(username, password),
      );
    } on ApiException catch (ajaxError) {
      throw lastError ?? ajaxError;
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
    final data = await _requestWithTrackedFallback(
        [
          '/services/sync-descriptions',
          '/services/sync-description',
          '/services/descriptions/sync',
          '/descriptions/sync',
          '/medyabayim/sync-descriptions',
          '/medyabayim/sync',
          '/scraper/sync-descriptions',
          '/services/sync-all',
        ],
        method: 'POST',
        body: const {
          'source': 'medyabayim',
          'fetch_first': true,
          'dry_run': false,
        });
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

  Future<Map<String, dynamic>> getUsers(
      {int page = 1, String search = ''}) async {
    var query = '?page=$page';
    if (search.isNotEmpty) query += '&search=${Uri.encodeComponent(search)}';
    final data = await _requestWithFallback([
      '/users$query',
      '/users/list$query',
      '/customers$query',
      '/members$query',
    ]);
    final payload = _asMap(data['data']);
    final rawItems =
        data['items'] ?? data['users'] ?? payload['items'] ?? payload['users'];

    final items = _asList(rawItems).map((item) {
      final map = _asMap(item);
      map['id'] = _asInt(map['id']);
      map['display_name'] =
          _pickString(map, ['display_name', 'name', 'full_name', 'username']);
      map['email'] = _pickString(map, ['email', 'user_email']);
      map['balance'] = map['balance'] ?? map['wallet_balance'] ?? 0;
      map['registered'] =
          _pickString(map, ['registered', 'created_at', 'date']);
      return map;
    }).toList();

    return {
      ...data,
      'items': items,
      'total': _asInt(data['total'],
          fallback: _asInt(payload['total'], fallback: items.length)),
      'pages': _asInt(data['pages'],
          fallback: _asInt(payload['pages'], fallback: 1)),
      'page': _asInt(data['page'],
          fallback: _asInt(payload['page'], fallback: page)),
    };
  }

  Future<Map<String, dynamic>> updateBalance(
    int userId,
    double amount,
    String type,
    String description,
  ) {
    final payload = {
      'amount': amount,
      'type': type,
      'description': description,
    };
    return _requestWithFallback(
      [
        '/users/$userId/balance',
        '/users/$userId/wallet',
        '/customers/$userId/balance',
      ],
      method: 'POST',
      body: payload,
    );
  }

  Future<Map<String, dynamic>> getUserDetail(int id) async {
    try {
      return await _requestWithFallback([
        '/users/$id/detail',
        '/users/$id',
        '/customers/$id',
        '/members/$id',
      ]);
    } on ApiException catch (error) {
      if (!_isMissingRoute(error)) rethrow;
      try {
        final users = await getUsers(search: '$id');
        final items = _asList(users['items']).map(_asMap).toList();
        final user = items.firstWhere(
          (item) => _asInt(item['id']) == id,
          orElse: () => <String, dynamic>{'id': id},
        );
        return {'success': true, 'user': user, 'supported': false};
      } catch (_) {
        return {
          'success': true,
          'user': <String, dynamic>{'id': id},
          'supported': false,
        };
      }
    }
  }

  Future<Map<String, dynamic>> getUserSessions(int id) async {
    try {
      final data = await _requestWithFallback([
        '/users/$id/sessions',
        '/users/$id/devices',
        '/users/$id/session-history',
      ]);
      final payload = _asMap(data['data']);
      final rawItems = data['items'] ??
          data['sessions'] ??
          payload['items'] ??
          payload['sessions'];
      return {
        ...data,
        'items': _asList(rawItems).map(_normalizeUserSession).toList(),
      };
    } on ApiException catch (error) {
      if (!_isMissingRoute(error)) rethrow;
      return {
        'success': true,
        'supported': false,
        'items': const <Map<String, dynamic>>[],
      };
    }
  }

  Future<Map<String, dynamic>> getUserLogs(int id) async {
    try {
      final data = await _requestWithFallback([
        '/users/$id/logs',
        '/users/$id/activity',
        '/users/$id/events',
      ]);
      final payload = _asMap(data['data']);
      final rawItems =
          data['items'] ?? data['logs'] ?? payload['items'] ?? payload['logs'];
      return {
        ...data,
        'items': _asList(rawItems).map(_normalizeUserLog).toList(),
      };
    } on ApiException catch (error) {
      if (!_isMissingRoute(error)) rethrow;
      return {
        'success': true,
        'supported': false,
        'items': const <Map<String, dynamic>>[],
      };
    }
  }

  Future<Map<String, dynamic>> getUserOrders(
    int id, {
    int page = 1,
  }) async {
    final query = '?page=$page';
    try {
      final data = await _requestWithFallback([
        '/users/$id/orders$query',
        '/users/$id/history$query',
        '/users/$id/orders/list$query',
        '/orders$query&user_id=$id',
        '/orders$query&customer_id=$id',
      ]);
      final payload = _asMap(data['data']);
      final rawItems = data['items'] ??
          data['orders'] ??
          payload['items'] ??
          payload['orders'];
      final items = _asList(rawItems).map(_normalizeUserOrder).toList();
      return {
        ...data,
        'items': items,
        'total': _asInt(data['total'],
            fallback: _asInt(payload['total'], fallback: items.length)),
        'page': _asInt(data['page'],
            fallback: _asInt(payload['page'], fallback: page)),
        'pages': _asInt(data['pages'],
            fallback: _asInt(payload['pages'], fallback: 1)),
      };
    } on ApiException catch (error) {
      if (!_isMissingRoute(error)) rethrow;
      try {
        final data = await getOrders(page: page, search: '$id');
        final allOrders =
            _asList(data['items']).map(_normalizeUserOrder).toList();
        final filtered =
            allOrders.where((order) => _orderBelongsToUser(order, id)).toList();
        return {
          'success': true,
          'supported': false,
          'items': filtered,
          'total': filtered.length,
          'page': page,
          'pages': 1,
        };
      } catch (_) {
        return {
          'success': true,
          'supported': false,
          'items': const <Map<String, dynamic>>[],
          'total': 0,
          'page': page,
          'pages': 1,
        };
      }
    }
  }

  Future<Map<String, dynamic>> getUser360(int id) async {
    Map<String, dynamic> detail = {
      'user': <String, dynamic>{'id': id}
    };
    Map<String, dynamic> ordersData = {'items': const <Map<String, dynamic>>[]};
    Map<String, dynamic> logsData = {'items': const <Map<String, dynamic>>[]};
    Map<String, dynamic> sessionsData = {
      'items': const <Map<String, dynamic>>[]
    };

    try {
      detail = await getUserDetail(id);
    } catch (_) {}
    try {
      ordersData = await getUserOrders(id);
    } catch (_) {}
    try {
      logsData = await getUserLogs(id);
    } catch (_) {}
    try {
      sessionsData = await getUserSessions(id);
    } catch (_) {}

    final user = _asMap(detail['user']).isNotEmpty
        ? _asMap(detail['user'])
        : _asMap(detail['data']).isNotEmpty
            ? _asMap(detail['data'])
            : _asMap(detail);

    final orders =
        _asList(ordersData['items']).map(_normalizeUserOrder).toList();
    final logs = _asList(logsData['items']).map(_normalizeUserLog).toList();
    final sessions =
        _asList(sessionsData['items']).map(_normalizeUserSession).toList();

    final topServicesMap = <String, Map<String, dynamic>>{};
    var totalSpent = 0.0;
    var completedOrders = 0;
    var cancelledOrders = 0;

    for (final order in orders) {
      final amount = _asDouble(order['amount']);
      totalSpent += amount;
      final status = '${order['status'] ?? ''}'.toLowerCase();
      if (status == 'completed' || status == 'success') {
        completedOrders++;
      }
      if (status == 'cancelled' || status == 'failed' || status == 'refunded') {
        cancelledOrders++;
      }

      final key =
          '${order['service_id'] ?? order['service_name'] ?? 'unknown'}';
      final bucket = topServicesMap[key] ??
          <String, dynamic>{
            'service_id': order['service_id'],
            'service_name': order['service_name'] ?? '-',
            'count': 0,
            'total_amount': 0.0,
            'last_order_date': '',
          };
      bucket['count'] = _asInt(bucket['count']) + 1;
      bucket['total_amount'] = _asDouble(bucket['total_amount']) + amount;
      final dateText = '${order['date'] ?? ''}';
      if (dateText.isNotEmpty) {
        bucket['last_order_date'] = dateText;
      }
      topServicesMap[key] = bucket;
    }

    final topServices = topServicesMap.values.toList()
      ..sort((a, b) => _asInt(b['count']).compareTo(_asInt(a['count'])));

    final ipMap = <String, Map<String, dynamic>>{};
    for (final item in [...logs, ...sessions]) {
      final ip = _pickString(item, ['ip', 'ip_address', 'user_ip']);
      if (ip.isEmpty) continue;
      final bucket = ipMap[ip] ??
          <String, dynamic>{
            'ip': ip,
            'count': 0,
            'last_seen': '',
            'country': '',
            'user_agent': '',
          };
      bucket['count'] = _asInt(bucket['count']) + 1;
      final dateText = _pickString(item, ['date', 'created_at', 'time']);
      if (dateText.isNotEmpty) bucket['last_seen'] = dateText;
      final country = _pickString(item, ['country', 'geo_country'], '');
      if (country.isNotEmpty) bucket['country'] = country;
      final ua = _pickString(item, ['user_agent', 'browser'], '');
      if (ua.isNotEmpty) bucket['user_agent'] = ua;
      ipMap[ip] = bucket;
    }
    final ipSummary = ipMap.values.toList()
      ..sort((a, b) => _asInt(b['count']).compareTo(_asInt(a['count'])));

    final timeline = <Map<String, dynamic>>[];
    for (final order in orders) {
      timeline.add({
        'type': 'order',
        'date': order['date'],
        'title': 'Siparis #${order['id']}',
        'message': '${order['service_name']} - ${order['status']}',
        'severity': 'info',
      });
    }
    for (final log in logs) {
      timeline.add({
        'type': 'activity',
        'date': log['date'],
        'title': '${log['action']}',
        'message': '${log['message']}',
        'severity': '${log['level']}',
      });
    }
    for (final session in sessions) {
      timeline.add({
        'type': 'session',
        'date': session['date'],
        'title': 'Oturum',
        'message': '${session['ip']} - ${session['device']}',
        'severity': 'low',
      });
    }
    timeline.sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

    final failedLogins = logs
        .where((log) =>
            '${log['action']}'.toLowerCase().contains('fail') ||
            '${log['action']}'.toLowerCase().contains('error'))
        .length;
    final blockedSignals = logs
        .where((log) =>
            '${log['action']}'.toLowerCase().contains('block') ||
            '${log['message']}'.toLowerCase().contains('block'))
        .length;
    final riskScore = (failedLogins * 8 +
            blockedSignals * 12 +
            (ipSummary.length > 3 ? 15 : 0))
        .clamp(0, 100);

    final metrics = <String, dynamic>{
      'total_orders': orders.length,
      'total_spent': double.parse(totalSpent.toStringAsFixed(2)),
      'completed_orders': completedOrders,
      'cancelled_orders': cancelledOrders,
      'avg_order_value': orders.isNotEmpty ? totalSpent / orders.length : 0.0,
      'unique_ips': ipSummary.length,
      'last_order_date':
          orders.isNotEmpty ? _pickString(orders.first, ['date'], '-') : '-',
      'risk_score': riskScore,
    };

    return {
      'success': true,
      'user': user,
      'orders': orders,
      'logs': logs,
      'sessions': sessions,
      'top_services': topServices.take(10).toList(),
      'ip_summary': ipSummary,
      'timeline': timeline,
      'metrics': metrics,
      'security': {
        'failed_logins': failedLogins,
        'blocked_signals': blockedSignals,
        'unique_ips': ipSummary.length,
      },
    };
  }

  Future<Map<String, dynamic>> blockUser(int id) => _requestWithFallback(
        [
          '/users/$id/block',
          '/users/$id/status',
          '/customers/$id/block',
        ],
        method: 'POST',
        body: {'status': 'blocked', 'action_type': 'block'},
      );

  Future<Map<String, dynamic>> resetUserPassword(int id) =>
      _requestWithFallback(
        [
          '/users/$id/reset-password',
          '/users/$id/password/reset',
          '/customers/$id/reset-password',
        ],
        method: 'POST',
      );

  Future<Map<String, dynamic>> getPayments({
    int page = 1,
    String status = '',
    String search = '',
    int perPage = 0,
  }) {
    var query = '?page=$page';
    if (status.isNotEmpty) query += '&status=${Uri.encodeComponent(status)}';
    if (search.isNotEmpty) query += '&search=${Uri.encodeComponent(search)}';
    if (perPage > 0) {
      query += '&per_page=$perPage&limit=$perPage';
    }
    return _request('/payments$query');
  }

  Future<Map<String, dynamic>> paymentAction(
    int id,
    String actionType, {
    String reason = '',
  }) {
    final body = <String, dynamic>{'action_type': actionType};
    if (reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
      body['note'] = reason.trim();
    }
    return _request('/payments/$id/action', method: 'POST', body: body);
  }

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
        throw ApiException('Kampanya guncelleme bu sunucuda desteklenmiyor');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCronStatus() => _request('/cron');

  Future<Map<String, dynamic>> runCronJob(String job) =>
      _request('/cron/run', method: 'POST', body: {'job': job});

  Future<Map<String, dynamic>> getSecurityOverview({int page = 1}) async {
    final security = await getSecurity(page: page);
    final payload = _asMap(security['data']);

    final scopes = <Map<String, dynamic>>[
      security,
      payload,
      _asMap(security['summary']),
      _asMap(security['stats']),
      _asMap(security['totals']),
      _asMap(security['today_stats']),
      _asMap(security['realtime']),
      _asMap(security['metrics']),
      _asMap(payload['summary']),
      _asMap(payload['stats']),
      _asMap(payload['totals']),
      _asMap(payload['today_stats']),
      _asMap(payload['realtime']),
      _asMap(payload['metrics']),
    ];

    int pickInt(List<String> keys, {int fallback = 0}) {
      for (final scope in scopes) {
        for (final key in keys) {
          final value = _asNullableInt(scope[key]);
          if (value != null) return value;
        }
      }
      return fallback;
    }

    double pickDouble(List<String> keys, {double fallback = 0}) {
      for (final scope in scopes) {
        for (final key in keys) {
          final value = scope[key];
          if (value == null) continue;
          return _asDouble(value, fallback: fallback);
        }
      }
      return fallback;
    }

    final blockedItems =
        _asList(security['items']).map((item) => _asMap(item)).toList();
    final events =
        _asList(security['events']).map(_normalizeSecurityLogItem).toList();

    final mergedEvents = <Map<String, dynamic>>[];
    final seen = <String>{};

    void appendLogs(List<dynamic> source) {
      for (final item in source) {
        final normalized = _normalizeSecurityLogItem(item);
        final signature =
            '${normalized['date']}|${normalized['ip']}|${normalized['event']}|${normalized['message']}';
        if (!seen.add(signature)) continue;
        mergedEvents.add(normalized);
      }
    }

    appendLogs(events);
    try {
      final logsData = await getSecurityLogs(page: 1);
      appendLogs(_asList(logsData['items']));
    } catch (_) {}

    final totalRequests = pickInt(
      [
        'total_requests',
        'requests_total',
        'request_count',
        'all_requests',
        'total',
      ],
      fallback: mergedEvents.length,
    );
    final blockedRequests = pickInt(
      [
        'blocked_requests',
        'blocked_attempts',
        'total_blocked',
        'blocked',
      ],
      fallback: blockedItems.length,
    );

    final stats = <String, dynamic>{
      'total_requests': totalRequests,
      'blocked_requests': blockedRequests,
      'failed_logins': pickInt([
        'failed_logins',
        'failed_attempts',
        'failed_login_attempts',
      ]),
      'high_risk_events': pickInt([
        'high_risk_events',
        'critical_events',
        'high_risk_count',
      ]),
      'active_blocks': pickInt([
        'active_blocks',
        'blocked_ips',
      ], fallback: blockedItems.length),
      'cf_threat_score': pickDouble([
        'cf_threat_score',
        'avg_threat_score',
        'threat_score',
      ]),
      'bot_percentage': pickDouble([
        'bot_percentage',
        'avg_bot_percentage',
      ]),
      'block_rate': totalRequests > 0
          ? ((blockedRequests / totalRequests) * 100).clamp(0, 100)
          : 0,
    };

    return {
      ...security,
      'stats': stats,
      'blocked_items': blockedItems,
      'events': mergedEvents,
    };
  }

  Future<Map<String, dynamic>> getSecurity({int page = 1}) async {
    try {
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
    } on ApiException catch (error) {
      if (!_isMissingRoute(error)) {
        rethrow;
      }
      return {
        'success': true,
        'supported': false,
        'items': const <Map<String, dynamic>>[],
        'events': const <Map<String, dynamic>>[],
        'page': page,
        'pages': 1,
        'message': 'Bu sunucuda security endpointi bulunmuyor.',
      };
    }
  }

  Future<Map<String, dynamic>> securityAction(String ip, String actionType) =>
      _request('/security/block',
          method: 'POST', body: {'ip': ip, 'action_type': actionType});

  Future<Map<String, dynamic>> getRateLimitSettings() async {
    try {
      final data = await _request('/security/rate-limit');
      final payload = _asMap(data['data']);
      final source = <String, dynamic>{...payload, ...data};
      final maxRequests = _asInt(
        source['max_requests_per_minute'] ??
            source['max_requests'] ??
            source['rate_limit_requests'] ??
            source['limit'],
        fallback: 60,
      );
      final windowSeconds = _asInt(
        source['window_seconds'] ??
            source['rate_limit_window'] ??
            source['window'],
        fallback: 60,
      );
      final banDurationMinutes = _asInt(
        source['ban_duration_minutes'] ??
            source['ban_duration'] ??
            source['block_duration_minutes'],
        fallback: 30,
      );

      return {
        ...data,
        ...payload,
        'enabled': _asBool(source['enabled'] ?? source['active']) ? 1 : 0,
        'max_requests': maxRequests,
        'max_requests_per_minute': maxRequests,
        'max_requests_per_ip':
            _asInt(source['max_requests_per_ip'], fallback: maxRequests),
        'window_seconds': windowSeconds,
        'ban_duration_minutes': banDurationMinutes,
        'whitelist': '${source['whitelist'] ?? source['ip_whitelist'] ?? ''}',
      };
    } on ApiException catch (e) {
      if (!_isMissingRouteError(e.message)) rethrow;
      return {
        'success': true,
        'enabled': 0,
        'max_requests': 60,
        'max_requests_per_minute': 60,
        'max_requests_per_ip': 60,
        'window_seconds': 60,
        'ban_duration_minutes': 30,
        'whitelist': '',
        'message':
            'Bu yedek eklenti surumunde rate limit endpointi bulunmuyor.',
      };
    }
  }

  Future<Map<String, dynamic>> saveRateLimitSettings(
      Map<String, dynamic> data) {
    final enabled = _asBool(data['enabled'] ?? data['active']) ? 1 : 0;
    final maxRequests = _asInt(
      data['max_requests_per_minute'] ??
          data['max_requests'] ??
          data['rate_limit_requests'] ??
          data['limit'],
      fallback: 60,
    );
    final windowSeconds = _asInt(
      data['window_seconds'] ?? data['rate_limit_window'] ?? data['window'],
      fallback: 60,
    );

    final payload = <String, dynamic>{
      ...data,
      'enabled': enabled,
      'active': enabled,
      'max_requests': maxRequests,
      'max_requests_per_minute': maxRequests,
      'rate_limit_requests': maxRequests,
      'window_seconds': windowSeconds,
      'rate_limit_window': windowSeconds,
      'max_requests_per_ip': _asInt(data['max_requests_per_ip'],
          fallback: _asInt(data['max_requests_per_minute'] ?? maxRequests,
              fallback: maxRequests)),
      'ban_duration_minutes': _asInt(
        data['ban_duration_minutes'] ??
            data['ban_duration'] ??
            data['block_duration_minutes'],
        fallback: 30,
      ),
      'whitelist': '${data['whitelist'] ?? data['ip_whitelist'] ?? ''}',
    };

    return _request('/security/rate-limit', method: 'POST', body: payload);
  }

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
      try {
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
      } on ApiException catch (fallbackError) {
        if (!_isMissingRouteError(fallbackError.message)) {
          rethrow;
        }
        return {
          'success': true,
          'supported': false,
          'items': const <Map<String, dynamic>>[],
          'page': page,
          'pages': 1,
          'total': 0,
          'message': 'Bu sunucuda security log endpointi bulunmuyor.',
        };
      }
    }
  }

  Future<Map<String, dynamic>> getSecuritySettingsBundle() async {
    Map<String, dynamic> settingsResponse = <String, dynamic>{};
    try {
      settingsResponse = await _requestWithFallback([
        '/security/settings',
        '/settings/security',
        '/settings',
      ]);
    } on ApiException catch (error) {
      if (!_isMissingRoute(error)) {
        rethrow;
      }
      try {
        settingsResponse = await getSettings();
      } on ApiException catch (fallbackError) {
        if (!_isMissingRoute(fallbackError)) {
          rethrow;
        }
        settingsResponse = <String, dynamic>{
          'success': true,
          'settings': <String, dynamic>{},
          'message':
              'Bu sunucuda guvenlik ayari endpointi bulunmuyor. Varsayilan degerler kullaniliyor.',
        };
      }
    }

    final payload = _asMap(settingsResponse['data']);
    var settings = _asMap(settingsResponse['settings']);
    if (settings.isEmpty) settings = _asMap(payload['settings']);
    if (settings.isEmpty) settings = _asMap(settingsResponse['security']);
    if (settings.isEmpty) settings = _asMap(payload['security']);
    if (settings.isEmpty)
      settings = _asMap(settingsResponse['security_settings']);
    if (settings.isEmpty) settings = _asMap(payload['security_settings']);
    if (settings.isEmpty) {
      settings = Map<String, dynamic>.from(settingsResponse);
      settings.removeWhere(
          (key, _) => key == 'success' || key == 'message' || key == 'data');
    }

    Map<String, dynamic> rateLimit;
    try {
      rateLimit = await getRateLimitSettings();
    } catch (_) {
      rateLimit = {
        'enabled': _asBool(settings['enable_rate_limiting']) ? 1 : 0,
        'max_requests': _asInt(settings['rate_limit_requests'], fallback: 60),
        'max_requests_per_minute':
            _asInt(settings['rate_limit_requests'], fallback: 60),
        'max_requests_per_ip':
            _asInt(settings['rate_limit_requests'], fallback: 60),
        'window_seconds': _asInt(settings['rate_limit_window'], fallback: 60),
        'ban_duration_minutes':
            _asInt(settings['block_duration'], fallback: 30) ~/ 60,
        'whitelist': '${settings['admin_ip_allowlist'] ?? ''}',
      };
    }

    final mergedSettings = <String, dynamic>{...settings};
    mergedSettings['enable_rate_limiting'] =
        _asBool(mergedSettings['enable_rate_limiting'] ?? rateLimit['enabled']);
    mergedSettings['rate_limit_requests'] = _asInt(
      mergedSettings['rate_limit_requests'] ?? rateLimit['max_requests'],
      fallback: 60,
    );
    mergedSettings['rate_limit_window'] = _asInt(
      mergedSettings['rate_limit_window'] ?? rateLimit['window_seconds'],
      fallback: 60,
    );

    return {
      'success': true,
      'settings': mergedSettings,
      'rate_limit': rateLimit,
      'raw_settings': settingsResponse,
    };
  }

  Future<Map<String, dynamic>> saveSecuritySettingsBundle({
    required Map<String, dynamic> settings,
    required Map<String, dynamic> rateLimit,
  }) async {
    final result = <String, dynamic>{'success': true};
    var anyEndpointHandled = false;

    if (settings.isNotEmpty) {
      final cleanSettings = Map<String, dynamic>.from(settings)
        ..removeWhere((key, _) => key.toString().startsWith('_'));
      try {
        result['settings'] = await saveSettings(cleanSettings);
        anyEndpointHandled = true;
      } on ApiException catch (error) {
        if (!_isMissingRoute(error)) {
          rethrow;
        }
        result['settings_supported'] = false;
        result['settings_error'] = error.message;
      }
    }

    if (rateLimit.isNotEmpty) {
      try {
        result['rate_limit'] = await saveRateLimitSettings(rateLimit);
        anyEndpointHandled = true;
      } on ApiException catch (error) {
        if (!_isMissingRoute(error)) {
          rethrow;
        }
        result['rate_limit_supported'] = false;
        result['rate_limit_error'] = error.message;
      }
    }

    if (!anyEndpointHandled) {
      throw ApiException(
          'Bu sunucuda guvenlik ayari kaydetme endpointi bulunamadi.');
    }

    return result;
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
    return _looksLikeRouteMessage(message);
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

  Map<String, dynamic> _normalizeUserOrder(dynamic item) {
    final data =
        item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    return {
      ...data,
      'id': _asInt(data['id'] ?? data['order_id']),
      'user_id': _asInt(data['user_id'] ?? data['uid']),
      'service_id': _asInt(data['service_id'] ?? data['sid']),
      'service_name':
          _pickString(data, ['service_name', 'service', 'name'], '-'),
      'status': _pickString(data, ['status', 'order_status'], 'pending'),
      'amount': _asDouble(
        data['amount'] ??
            data['total'] ??
            data['price'] ??
            data['charge'] ??
            data['cost'],
      ),
      'date':
          _pickString(data, ['date', 'created_at', 'time', 'order_date'], '-'),
    };
  }

  Map<String, dynamic> _normalizeUserLog(dynamic item) {
    final data =
        item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    return {
      ...data,
      'action': _pickString(data, ['action', 'event', 'type'], 'activity'),
      'message':
          _pickString(data, ['message', 'details', 'reason', 'note'], '-'),
      'level': _pickString(data, ['level', 'risk', 'severity', 'type'], 'info'),
      'date':
          _pickString(data, ['date', 'created_at', 'time', 'timestamp'], '-'),
      'ip': _pickString(data, ['ip', 'ip_address', 'user_ip', 'address'], '-'),
    };
  }

  Map<String, dynamic> _normalizeUserSession(dynamic item) {
    final data =
        item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
    return {
      ...data,
      'ip': _pickString(data, ['ip', 'ip_address', 'user_ip', 'address'], '-'),
      'date':
          _pickString(data, ['date', 'created_at', 'time', 'last_seen'], '-'),
      'device': _pickString(data, ['device', 'browser', 'user_agent'], '-'),
      'country': _pickString(data, ['country', 'geo_country', 'location'], ''),
      'user_agent': _pickString(data, ['user_agent', 'browser'], ''),
    };
  }

  bool _orderBelongsToUser(Map<String, dynamic> order, int userId) {
    final uid = _asInt(order['user_id']);
    if (uid > 0 && uid == userId) return true;
    final raw =
        '${order['user'] ?? order['customer'] ?? order['username'] ?? ''}'
            .trim();
    if (raw == '$userId') return true;
    return false;
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
