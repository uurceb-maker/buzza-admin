import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/admin_api.dart';
import '../../widgets/stat_card.dart';

class SecurityTab extends StatefulWidget {
  const SecurityTab({super.key});

  @override
  State<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;
  bool _blockedLoading = false;
  bool _loadingLogs = false;
  bool _loadingSettings = false;
  bool _saving = false;

  Map<String, dynamic> _overview = {};
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _rate = {};
  List<Map<String, dynamic>> _blocked = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _logs = [];

  int _blockedPage = 1;
  int _blockedPages = 1;
  int _logsPage = 1;
  int _logsPages = 1;

  final _ipCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _level = 'all';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _loadOverview();
  }

  @override
  void dispose() {
    _tab.dispose();
    _ipCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  int _asInt(dynamic v, {int fb = 0}) {
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse('$v') ?? fb;
  }

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final t = '$v'.trim().toLowerCase();
    return t == '1' || t == 'true' || t == 'yes' || t == 'on' || t == 'active';
  }

  Future<void> _loadOverview() async {
    setState(() => _loading = true);
    try {
      final d = await AdminApi().getSecurityOverview(page: _blockedPage);
      if (!mounted) return;
      setState(() {
        _overview = d;
        _blocked = (d['blocked_items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _events = (d['events'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _blockedPage = _asInt(d['page'], fb: _blockedPage);
        _blockedPages = _asInt(d['pages'], fb: 1);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _loadBlocked({int? page}) async {
    if (page != null) {
      _blockedPage = page;
    }
    setState(() => _blockedLoading = true);
    try {
      final d = await AdminApi().getSecurity(page: _blockedPage);
      if (!mounted) return;
      setState(() {
        _blocked = (d['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _blockedPage = _asInt(d['page'], fb: _blockedPage);
        _blockedPages = _asInt(d['pages'], fb: 1);
        _blockedLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _blockedLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _loadLogs({int? page, bool force = false}) async {
    if (_logs.isNotEmpty && !force && page == null) return;
    if (page != null) _logsPage = page;
    setState(() => _loadingLogs = true);
    try {
      final d = await AdminApi().getSecurityLogs(page: _logsPage);
      if (!mounted) return;
      setState(() {
        _logs = (d['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _logsPage = _asInt(d['page'], fb: _logsPage);
        _logsPages = _asInt(d['pages'], fb: 1);
        _loadingLogs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingLogs = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _loadSettings() async {
    if (_settings.isNotEmpty) return;
    setState(() => _loadingSettings = true);
    try {
      final d = await AdminApi().getSecuritySettingsBundle();
      if (!mounted) return;
      setState(() {
        _settings = Map<String, dynamic>.from(
            (d['settings'] as Map?) ?? <String, dynamic>{});
        _rate = Map<String, dynamic>.from(
            (d['rate_limit'] as Map?) ?? <String, dynamic>{});
        _loadingSettings = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSettings = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      await AdminApi()
          .saveSecuritySettingsBundle(settings: _settings, rateLimit: _rate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Guvenlik ayarlari kaydedildi'),
            backgroundColor: AppTheme.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _blockAction(String ip, String action) async {
    try {
      await AdminApi().securityAction(ip, action);
      await _loadBlocked(page: _blockedPage);
      await _loadOverview();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              action == 'block' ? '$ip engellendi' : '$ip engeli kaldirildi'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    final s = _search.trim().toLowerCase();
    return _logs.where((e) {
      final level = '${e['type'] ?? e['level'] ?? 'info'}'.toLowerCase();
      if (_level != 'all' && _level != level) return false;
      if (s.isEmpty) return true;
      final text =
          '${e['ip'] ?? ''} ${e['event'] ?? ''} ${e['message'] ?? ''} ${e['endpoint'] ?? ''}'
              .toLowerCase();
      return text.contains(s);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppTheme.bgCard,
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primary,
            tabs: const [
              Tab(text: 'Genel Bakis'),
              Tab(text: 'Engelli IP'),
              Tab(text: 'Olay Takibi'),
              Tab(text: 'Guvenlik Ayarlari'),
            ],
            onTap: (i) {
              if (i == 1 && _blocked.isEmpty) _loadBlocked();
              if (i == 2) _loadLogs();
              if (i == 3) _loadSettings();
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildOverview(),
              _buildBlocked(),
              _buildLogs(),
              _buildSettings(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverview() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }

    final stats = Map<String, dynamic>.from(
        (_overview['stats'] as Map?) ?? <String, dynamic>{});
    final total = _asInt(
        stats['total_requests'] ??
            stats['requests_total'] ??
            stats['request_count'],
        fb: _events.length);
    final blocked = _asInt(
        stats['blocked_requests'] ??
            stats['blocked_attempts'] ??
            stats['blocked'],
        fb: _blocked.length);
    final failed = _asInt(stats['failed_logins'] ?? stats['failed_attempts']);
    final high = _asInt(stats['high_risk_events'] ??
        stats['critical_events'] ??
        stats['high_risk_count']);
    final rate = total > 0 ? (blocked / total) * 100 : 0.0;

    return RefreshIndicator(
      onRefresh: _loadOverview,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.glassDecoration(radius: 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Guvenlik Analiz Merkezi',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              Text('Blok orani: %${rate.toStringAsFixed(1)}',
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                  value: (rate / 100).clamp(0, 1),
                  minHeight: 8,
                  color: rate >= 12 ? AppTheme.error : AppTheme.success,
                  backgroundColor: AppTheme.bgSurface),
            ]),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 12) / 2;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.public_rounded,
                      label: 'Toplam Istek',
                      value: '$total',
                      subtitle: 'Canli trafik',
                      iconColor: AppTheme.info)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.block_rounded,
                      label: 'Engellenen Istek',
                      value: '$blocked',
                      subtitle: 'Aktif savunma',
                      iconColor: AppTheme.error)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.key_off_rounded,
                      label: 'Hatali Giris',
                      value: '$failed',
                      subtitle: 'Brute force',
                      iconColor: AppTheme.warning)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Yuksek Risk',
                      value: '$high',
                      subtitle: 'Anlik olay',
                      iconColor: AppTheme.accentPink)),
            ]);
          }),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.glassDecoration(radius: 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Son Guvenlik Olaylari',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (_events.isEmpty)
                const Text('Kayitli olay bulunamadi.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12))
              else
                ..._events.take(6).map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                          '${e['date'] ?? '-'}  ${e['event'] ?? 'security'}  ${e['ip'] ?? '-'}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    )),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocked() {
    return RefreshIndicator(
      onRefresh: () => _loadBlocked(page: _blockedPage),
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.glassDecoration(radius: 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Manuel IP Engelleme',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(
                  controller: _ipCtrl,
                  decoration: AppTheme.inputDecoration(
                      hint: 'Orn: 203.0.113.5',
                      label: 'IP adresi',
                      prefixIcon: Icons.language_rounded)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ip = _ipCtrl.text.trim();
                    if (ip.isEmpty) return;
                    await _blockAction(ip, 'block');
                    _ipCtrl.clear();
                  },
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('IP Engelle'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (_blockedLoading && _blocked.isEmpty)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppTheme.primary)))
          else if (_blocked.isEmpty)
            Container(
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.glassDecoration(radius: 14),
                child: const Text('Aktif engelli IP bulunmuyor.',
                    style: TextStyle(color: AppTheme.textMuted)))
          else
            ..._blocked.map((b) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: AppTheme.glassDecoration(radius: 14),
                  child: Row(children: [
                    const Icon(Icons.block_rounded,
                        color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            '${b['ip'] ?? '-'}  -  ${b['reason'] ?? 'Engellendi'}',
                            style: const TextStyle(fontSize: 11))),
                    TextButton(
                        onPressed: () => _blockAction('${b['ip']}', 'unblock'),
                        child: const Text('Kaldir')),
                  ]),
                )),
          if (_blockedPages > 1)
            _pager(
              page: _blockedPage,
              pages: _blockedPages,
              onPrev: _blockedPage > 1
                  ? () => _loadBlocked(page: _blockedPage - 1)
                  : null,
              onNext: _blockedPage < _blockedPages
                  ? () => _loadBlocked(page: _blockedPage + 1)
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildLogs() {
    final rows = _filteredLogs;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.glassDecoration(radius: 14),
          child: Row(children: [
            Expanded(
                child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: AppTheme.inputDecoration(
                        hint: 'IP veya olay ara',
                        label: 'Ara',
                        prefixIcon: Icons.search_rounded))),
            const SizedBox(width: 8),
            DropdownButton<String>(
                value: _level,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tum')),
                  DropdownMenuItem(value: 'critical', child: Text('Kritik')),
                  DropdownMenuItem(value: 'error', child: Text('Hata')),
                  DropdownMenuItem(value: 'warning', child: Text('Uyari')),
                  DropdownMenuItem(value: 'info', child: Text('Bilgi')),
                  DropdownMenuItem(value: 'low', child: Text('Dusuk')),
                  DropdownMenuItem(value: 'medium', child: Text('Orta')),
                  DropdownMenuItem(value: 'high', child: Text('Yuksek'))
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _level = v);
                }),
            IconButton(
                onPressed: () => _loadLogs(force: true),
                icon: const Icon(Icons.refresh_rounded)),
          ]),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _loadLogs(force: true),
          color: AppTheme.primary,
          child: _loadingLogs && rows.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    if (rows.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                              child: Text('Filtreye uygun log bulunamadi',
                                  style: TextStyle(color: AppTheme.textMuted))))
                    else
                      ...rows.map((e) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: AppTheme.glassDecoration(radius: 12),
                            child: Text(
                                '${e['date'] ?? '-'}  ${e['ip'] ?? '-'}  ${e['event'] ?? 'security'}\n${e['message'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)),
                          )),
                    if (_logsPages > 1)
                      _pager(
                        page: _logsPage,
                        pages: _logsPages,
                        onPrev: _logsPage > 1
                            ? () => _loadLogs(page: _logsPage - 1, force: true)
                            : null,
                        onNext: _logsPage < _logsPages
                            ? () => _loadLogs(page: _logsPage + 1, force: true)
                            : null,
                      ),
                  ],
                ),
        ),
      ),
    ]);
  }

  Widget _buildSettings() {
    if (_loadingSettings) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_settings.isEmpty && _rate.isEmpty) {
      return Center(
          child: ElevatedButton.icon(
              onPressed: _loadSettings,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Ayar yukle')));
    }

    Widget nField(Map<String, dynamic> target, String key, String label) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: TextEditingController(text: '${target[key] ?? ''}'),
          keyboardType: TextInputType.number,
          onChanged: (v) => target[key] = int.tryParse(v) ?? v,
          decoration: AppTheme.inputDecoration(
              hint: label, label: label, prefixIcon: Icons.numbers_rounded),
        ),
      );
    }

    Widget tField(Map<String, dynamic> target, String key, String label) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: TextEditingController(text: '${target[key] ?? ''}'),
          onChanged: (v) => target[key] = v,
          decoration: AppTheme.inputDecoration(
              hint: label, label: label, prefixIcon: Icons.edit_rounded),
        ),
      );
    }

    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.glassDecoration(radius: 16),
            child: Column(children: [
              for (final row in const [
                ['enable_rest_api_security', 'REST API korumasi'],
                ['enable_rate_limiting', 'Rate limit'],
                ['auto_block_suspicious', 'Supheli trafik engeli'],
                ['enable_admin_ip_restriction', 'Admin IP kisiti'],
                ['enable_cloudflare_bridge', 'Cloudflare koprusu'],
                ['enable_risk_engine', 'Risk motoru'],
                ['enable_fraud_detection', 'Fraud tespiti'],
                ['enable_behavior_tracking', 'Davranis takibi'],
              ])
                SwitchListTile(
                  value: _asBool(_settings[row[0]]),
                  title: Text(row[1]),
                  onChanged: (v) =>
                      setState(() => _settings[row[0]] = v ? 1 : 0),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.glassDecoration(radius: 16),
              child: Column(children: [
                nField(
                    _settings, 'failed_login_threshold', 'Hatali giris esigi'),
                nField(_settings, 'block_duration', 'Blok suresi (sn)'),
                nField(
                    _settings, 'cf_threat_high_threshold', 'CF tehdit esigi'),
                nField(_settings, 'jwt_token_ttl_hours', 'JWT suresi (saat)'),
                nField(_settings, 'api_rate_limit_per_minute',
                    'API dakika limiti'),
                nField(_settings, 'risk_score_payment_threshold',
                    'Odeme risk esigi'),
                nField(
                    _settings, 'risk_score_block_threshold', 'Blok risk esigi'),
                nField(_rate, 'max_requests_per_minute', 'Rate dakika limiti'),
                nField(_rate, 'max_requests_per_ip', 'Rate IP limiti'),
                nField(_rate, 'window_seconds', 'Rate pencere (sn)'),
                nField(_rate, 'ban_duration_minutes', 'Ban suresi (dk)'),
                tField(_rate, 'whitelist', 'Whitelist IP'),
                tField(_settings, 'admin_ip_allowlist', 'Admin IP allowlist'),
              ])),
          const SizedBox(height: 12),
          ElevatedButton.icon(
              onPressed: _saving ? null : _saveSettings,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: Text(
                  _saving ? 'Kaydediliyor...' : 'Guvenlik ayarlarini kaydet')),
        ]);
  }

  Widget _pager(
      {required int page,
      required int pages,
      required VoidCallback? onPrev,
      required VoidCallback? onNext}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.glassDecoration(radius: 12),
      child: Row(children: [
        Expanded(
            child:
                OutlinedButton(onPressed: onPrev, child: const Text('Onceki'))),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('$page / $pages',
                style: const TextStyle(color: AppTheme.textMuted))),
        Expanded(
            child: OutlinedButton(
                onPressed: onNext, child: const Text('Sonraki'))),
      ]),
    );
  }
}
