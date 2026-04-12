import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'admin_api.dart';

// ─── Arka plan Workmanager callback ─────────────────────────────────────────
const String _bgTaskName = 'buzza_admin_support_sync_task';

@pragma('vm:entry-point')
void supportNotificationCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task == _bgTaskName || task == Workmanager.iOSBackgroundTask) {
      await SupportNotificationService.runBackgroundSync();
    }
    return true;
  });
}

// ─── Servis ─────────────────────────────────────────────────────────────────
class SupportNotificationService with WidgetsBindingObserver {
  SupportNotificationService._();
  static final SupportNotificationService instance =
      SupportNotificationService._();

  // ─ Sabitler ─
  static const String _bgUniqueTask  = 'buzza_admin_support_sync_unique';
  static const String iOSTaskId      = 'com.buzza.buzza_admin.support_sync';
  static const String _prefLastId    = 'buzza_admin_last_support_msg_id';
  static const String _channelId     = 'buzza_admin_support_v1';
  static const String _channelName   = 'Destek Bildirimleri';
  static const String _channelDesc   = 'Yeni müşteri destek talepleri';
  static const Duration _pollInterval = Duration(seconds: 30);

  // ─ Durum ─
  final FlutterLocalNotificationsPlugin _ln = FlutterLocalNotificationsPlugin();
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  Timer? _pollTimer;
  bool _initialized  = false;
  bool _polling      = false;
  bool _isForeground = true;
  bool supportTabActive = false;

  // ─── initialize ─────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);
    await _initLocalNotifications();

    // WorkManager – yalnızca Android/iOS
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await Workmanager().initialize(
        supportNotificationCallbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Workmanager().registerPeriodicTask(
          _bgUniqueTask,
          _bgTaskName,
          frequency: const Duration(minutes: 15),
          initialDelay: const Duration(minutes: 3),
          existingWorkPolicy: ExistingWorkPolicy.keep,
          constraints: Constraints(networkType: NetworkType.connected),
          backoffPolicy: BackoffPolicy.exponential,
          backoffPolicyDelay: const Duration(minutes: 1),
        );
      }
    }

    // İlk kontrol + periyodik polling (ön plan)
    unawaited(_poll(silentBootstrap: true));
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  // ─── Yaşam döngüsü ──────────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _initialized = false;
  }

  // ─── Ön plan polling ────────────────────────────────────────────────────
  Future<void> _poll({bool silentBootstrap = false}) async {
    if (_polling) return;
    _polling = true;
    try {
      final prefs   = await SharedPreferences.getInstance();
      final sinceId  = prefs.getInt(_prefLastId) ?? 0;
      final api      = AdminApi();

      final result   = await api.getSupportUnread(sinceId: sinceId);
      final items    = result['items'] as List<dynamic>? ?? [];
      final count    = result['count'] as int? ?? items.length;

      unreadCount.value = count;

      if (items.isEmpty || silentBootstrap) {
        // İlk çalışmada sadece son ID'yi kaydet
        if (items.isNotEmpty && sinceId == 0) {
          final firstId = _resolveId(items.first as Map<String, dynamic>);
          if (firstId > 0) await prefs.setInt(_prefLastId, firstId);
        }
        return;
      }

      // En yeni ID'yi kaydet
      int maxId = sinceId;
      for (final raw in items) {
        final id = _resolveId(raw as Map<String, dynamic>);
        if (id > maxId) maxId = id;
      }
      if (maxId > sinceId) await prefs.setInt(_prefLastId, maxId);

      // Bildirim göster (destek sekmesi aktif değilse)
      if (!supportTabActive) {
        await _showNotification(
          items.first as Map<String, dynamic>,
          extraCount: items.length - 1,
        );
      }
    } catch (_) {
      // Sessizce geç — polling akışını bloklamasın
    } finally {
      _polling = false;
    }
  }

  // ─── Arka plan sync (WorkManager tarafından çağrılır) ───────────────────
  static Future<void> runBackgroundSync() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final sinceId  = prefs.getInt(_prefLastId) ?? 0;
      final api      = AdminApi();

      // Oturum yoksa SharedPreferences'tan token ile devam et
      if (!api.hasToken) {
        final token = prefs.getString('buzza_admin_token') ?? '';
        if (token.isNotEmpty) api.setToken(token);
      }

      final result = await api.getSupportUnread(sinceId: sinceId);
      final items  = result['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) return;

      int maxId = sinceId;
      for (final raw in items) {
        final id = _resolveId(raw as Map<String, dynamic>);
        if (id > maxId) maxId = id;
      }
      if (maxId > sinceId) await prefs.setInt(_prefLastId, maxId);

      await instance._showNotification(
        items.first as Map<String, dynamic>,
        extraCount: items.length - 1,
      );
    } catch (_) {}
  }

  // ─── Bildirim göster ────────────────────────────────────────────────────
  Future<void> _initLocalNotifications() async {
    const android  = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin   = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _ln.initialize(
      const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
    );

    // Android izin iste
    final androidPlugin =
        _ln.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _showNotification(
    Map<String, dynamic> item, {
    int extraCount = 0,
  }) async {
    final subject  = _str(item['subject'], fallback: 'Yeni Destek Talebi');
    final customer = _str(item['customer_name'],
        fallback: _str(item['customer_email'], fallback: 'Müşteri'));
    final titleBase = '$customer yazdı';
    final title     = extraCount > 0 ? '$titleBase (+$extraCount)' : titleBase;
    final body      = subject;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('bildirim'),
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'bildirim.wav',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    final id = _resolveId(item) > 0
        ? _resolveId(item)
        : DateTime.now().millisecondsSinceEpoch.remainder(1000000);

    await _ln.show(
      id,
      title,
      body,
      details,
      payload: 'support_ticket:${item['ticket_id'] ?? ''}',
    );
  }

  // ─── Yardımcılar ────────────────────────────────────────────────────────
  static int _resolveId(Map<String, dynamic> item) {
    final v = item['id'];
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  static String _str(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    final t = '$v'.trim();
    return t.isEmpty ? fallback : t;
  }
}
