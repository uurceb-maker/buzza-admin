import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api.dart';

class SecurityTab extends StatefulWidget {
  const SecurityTab({super.key});
  @override
  State<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _blocked = [];
  int _page = 1, _pages = 1;
  bool _loading = true;

  // Rate limit settings
  Map<String, dynamic> _rlSettings = {};
  bool _rlLoading = false, _rlSaving = false;

  // Logs
  List<dynamic> _logs = [];
  bool _logLoading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await AdminApi().getSecurity(page: _page);
      setState(() {
        _blocked = d['items'] as List? ?? [];
        _pages = d['pages'] ?? 1;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _loadRateLimit() async {
    if (_rlSettings.isNotEmpty) return;
    setState(() => _rlLoading = true);
    try {
      final d = await AdminApi().getRateLimitSettings();
      setState(() { _rlSettings = d; _rlLoading = false; });
    } catch (e) {
      setState(() => _rlLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _saveRateLimit() async {
    setState(() => _rlSaving = true);
    try {
      await AdminApi().saveRateLimitSettings(_rlSettings);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rate limit ayarları kaydedildi ✅'), backgroundColor: AppTheme.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
    setState(() => _rlSaving = false);
  }

  Future<void> _loadLogs() async {
    if (_logs.isNotEmpty) return;
    setState(() => _logLoading = true);
    try {
      final d = await AdminApi().getSecurityLogs();
      setState(() { _logs = d['items'] as List? ?? []; _logLoading = false; });
    } catch (e) {
      setState(() => _logLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _toggleBlock(String ip, String action) async {
    try {
      await AdminApi().securityAction(ip, action);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(action == 'block' ? '$ip engellendi' : '$ip engeli kaldırıldı'),
        backgroundColor: AppTheme.success,
      ));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppTheme.bgCard,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primary,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'Engelli IP'), Tab(text: 'Rate Limit'), Tab(text: 'Güvenlik Logları')],
            onTap: (i) {
              if (i == 1) _loadRateLimit();
              if (i == 2) _loadLogs();
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [_buildBlockedList(), _buildRateLimitSettings(), _buildSecurityLogs()],
          ),
        ),
      ],
    );
  }

  // ═══ Tab 1: Blocked IPs ═══
  Widget _buildBlockedList() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: _blocked.isEmpty
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_rounded, size: 48, color: AppTheme.success),
                SizedBox(height: 12),
                Text('Engelli IP yok', style: TextStyle(color: AppTheme.textMuted)),
              ],
            ))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _blocked.length,
              itemBuilder: (ctx, i) => _buildBlockedCard(_blocked[i]),
            ),
    );
  }

  Widget _buildBlockedCard(dynamic ip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassDecoration(radius: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.block_rounded, size: 18, color: AppTheme.error),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ip['ip'] ?? '-'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                Text('${ip['reason'] ?? '-'} • ${ip['date'] ?? '-'}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (ip['type'] == 'auto' ? AppTheme.warning : AppTheme.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ip['type'] == 'auto' ? 'Otomatik' : 'Manuel',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: ip['type'] == 'auto' ? AppTheme.warning : AppTheme.primary),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.success),
            onPressed: () => _toggleBlock('${ip['ip']}', 'unblock'),
            tooltip: 'Engeli Kaldır',
          ),
        ],
      ),
    );
  }

  // ═══ Tab 2: Rate Limit Settings ═══
  Widget _buildRateLimitSettings() {
    if (_rlLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Enabled toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassDecoration(radius: 16),
          child: Column(
            children: [
              Row(children: [
                const Icon(Icons.shield_rounded, size: 20, color: AppTheme.primary),
                const SizedBox(width: 10),
                const Expanded(child: Text('Otomatik Rate Limiting', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                Switch(
                  value: _rlSettings['enabled'] == true || _rlSettings['enabled'] == 1,
                  onChanged: (v) => setState(() => _rlSettings['enabled'] = v ? 1 : 0),
                  activeTrackColor: AppTheme.primary,
                ),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 14, color: AppTheme.info),
                  SizedBox(width: 8),
                  Expanded(child: Text('Aktifken, belirlenen limitleri aşan IP\'ler otomatik engellenir.', style: TextStyle(fontSize: 11, color: AppTheme.info))),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Settings fields
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassDecoration(radius: 16),
          child: Column(
            children: [
              _rlField('max_requests_per_minute', 'Dak. / Max İstek (Global)', Icons.speed_rounded),
              _rlField('max_requests_per_ip', 'Dak. / Max İstek (IP Başına)', Icons.person_pin_rounded),
              _rlField('ban_duration_minutes', 'Otomatik Ban Süresi (dk)', Icons.timer_rounded),
              const SizedBox(height: 12),
              TextField(
                controller: TextEditingController(text: '${_rlSettings['whitelist'] ?? ''}'),
                maxLines: 3,
                decoration: AppTheme.inputDecoration(hint: 'Whitelist IP\'ler (virgülle ayırın)', prefixIcon: Icons.verified_user, label: 'Whitelist'),
                onChanged: (v) => _rlSettings['whitelist'] = v,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Save button
        ElevatedButton.icon(
          onPressed: _rlSaving ? null : _saveRateLimit,
          icon: _rlSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(_rlSaving ? 'Kaydediliyor...' : 'Ayarları Kaydet'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        ),
      ],
    );
  }

  Widget _rlField(String key, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: TextEditingController(text: '${_rlSettings[key] ?? ''}'),
        keyboardType: TextInputType.number,
        decoration: AppTheme.inputDecoration(hint: label, prefixIcon: icon, label: label),
        onChanged: (v) => _rlSettings[key] = v,
      ),
    );
  }

  // ═══ Tab 3: Security Logs ═══
  Widget _buildSecurityLogs() {
    if (_logLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_rounded, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('Log bulunamadı', style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadLogs,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Logları Yükle'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _logs.clear();
        await _loadLogs();
      },
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (ctx, i) {
          final l = _logs[i];
          final level = '${l['level'] ?? 'info'}';
          Color levelColor;
          switch (level) {
            case 'warning': levelColor = AppTheme.warning; break;
            case 'error':
            case 'critical': levelColor = AppTheme.error; break;
            default: levelColor = AppTheme.info; break;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.glassDecoration(radius: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: levelColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('${l['ip'] ?? '-'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                        const Spacer(),
                        Text('${l['date'] ?? '-'}', style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                      ]),
                      const SizedBox(height: 2),
                      Text('${l['method'] ?? '-'} ${l['endpoint'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      if (l['message'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('${l['message']}', style: TextStyle(fontSize: 10, color: levelColor)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
