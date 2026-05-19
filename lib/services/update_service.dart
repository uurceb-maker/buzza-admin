import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Otomatik guncelleme kontrolu (Buzza Admin).
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String _manifestUrl =
      'https://buzza.com.tr/downloads/version.json';
  static const String _appKey = 'admin';
  static const String _prefsLastCheck = 'admin_update_last_check_ts';
  static const String _prefsSkippedVersion = 'admin_update_skipped_version';
  static const Duration _checkInterval = Duration(hours: 6);

  bool _checking = false;

  Future<void> checkForUpdate(
    BuildContext context, {
    bool force = false,
    bool silent = false,
  }) async {
    if (_checking) return;
    _checking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_prefsLastCheck) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force &&
          now - lastCheck < _checkInterval.inMilliseconds &&
          lastCheck > 0) {
        return;
      }

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final manifest = await _fetchManifest();
      if (manifest == null) return;

      final appBlock = manifest[_appKey];
      if (appBlock is! Map) return;

      final latestVersion = '${appBlock['version'] ?? ''}'.trim();
      final latestBuild =
          int.tryParse('${appBlock['build'] ?? ''}'.trim()) ?? 0;
      final minSupported =
          '${appBlock['min_supported_version'] ?? '0.0.0'}'.trim();
      final forceUpdate = appBlock['force_update'] == true;
      final apkUrl = '${appBlock['apk_url'] ?? ''}'.trim();
      final changelog = (appBlock['changelog'] is List)
          ? List<String>.from(
              (appBlock['changelog'] as List).map((e) => e.toString()))
          : <String>[];

      if (latestVersion.isEmpty || apkUrl.isEmpty) return;
      await prefs.setInt(_prefsLastCheck, now);

      final isOutdated = _compareVersions(latestVersion, currentVersion) > 0 ||
          (latestBuild > 0 &&
              latestBuild > currentBuild &&
              _compareVersions(latestVersion, currentVersion) >= 0);

      if (!isOutdated) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Uygulamaniz guncel.'),
            duration: Duration(seconds: 2),
          ));
        }
        return;
      }

      final skipped = prefs.getString(_prefsSkippedVersion) ?? '';
      if (!force && !forceUpdate && skipped == latestVersion) return;

      final mustForce =
          forceUpdate || _compareVersions(minSupported, currentVersion) > 0;

      if (!context.mounted) return;
      await _showUpdateDialog(
        context,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        changelog: changelog,
        apkUrl: apkUrl,
        forceUpdate: mustForce,
      );
    } catch (_) {
      // sessiz
    } finally {
      _checking = false;
    }
  }

  Future<Map<String, dynamic>?> _fetchManifest() async {
    try {
      final url = '$_manifestUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      final res = await http
          .get(Uri.parse(url), headers: {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) return body;
      return null;
    } catch (_) {
      return null;
    }
  }

  int _compareVersions(String a, String b) {
    final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    while (pa.length < len) {
      pa.add(0);
    }
    while (pb.length < len) {
      pb.add(0);
    }
    for (var i = 0; i < len; i++) {
      if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
    }
    return 0;
  }

  Future<void> _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required List<String> changelog,
    required String apkUrl,
    required bool forceUpdate,
  }) async {
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.system_update_rounded, color: theme.primaryColor),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Guncelleme Var',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'v$currentVersion  ->  v$latestVersion',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                if (changelog.isNotEmpty)
                  ...changelog.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 6, right: 8),
                              child: Icon(Icons.circle, size: 6),
                            ),
                            Expanded(
                                child: Text(c,
                                    style: const TextStyle(fontSize: 14))),
                          ],
                        ),
                      ))
                else
                  const Text('Yeni bir surum yayinlandi.',
                      style: TextStyle(fontSize: 14)),
                if (forceUpdate) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.25)),
                    ),
                    child: const Text(
                      'Bu guncelleme zorunludur.',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(_prefsSkippedVersion, latestVersion);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Sonra'),
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded),
              label: const Text('Guncelle'),
              onPressed: () async {
                final uri = Uri.parse(apkUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
                if (!forceUpdate && ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
