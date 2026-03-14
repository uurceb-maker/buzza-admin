import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api.dart';
import '../../widgets/glass_box.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _settings = {};
  String _errorLog = '';
  bool _loading = true;
  bool _saving = false;
  bool _logLoading = false;
  late TabController _tabCtrl;

  // Sync states
  bool _syncingServices = false;
  bool _syncingCategories = false;
  bool _syncingDescriptions = false;
  bool _syncingAll = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await AdminApi().getSettings();
      setState(() {
        _settings = d;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AdminApi().saveSettings(_settings);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ayarlar kaydedildi ✅'),
            backgroundColor: AppTheme.success));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
    setState(() => _saving = false);
  }

  Future<void> _loadErrorLog() async {
    setState(() => _logLoading = true);
    try {
      final d = await AdminApi().getErrorLog();
      setState(() {
        _errorLog = d['content'] ?? 'Boş';
        _logLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorLog = 'Hata: $e';
        _logLoading = false;
      });
    }
  }

  Future<void> _runSync(String type) async {
    switch (type) {
      case 'services':
        setState(() => _syncingServices = true);
        break;
      case 'categories':
        setState(() => _syncingCategories = true);
        break;
      case 'descriptions':
        setState(() => _syncingDescriptions = true);
        break;
      case 'all':
        setState(() => _syncingAll = true);
        break;
    }
    try {
      late final Map<String, dynamic> result;
      switch (type) {
        case 'services':
          result = await AdminApi().syncServices();
          break;
        case 'categories':
          result = await AdminApi().syncCategories();
          break;
        case 'descriptions':
          result = await AdminApi().syncDescriptions();
          break;
        case 'all':
          result = await AdminApi().syncAll();
          break;
        default:
          result = const <String, dynamic>{};
      }
      if (mounted) {
        final hasErrors = _syncHasErrors(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_syncResultText(type, result)),
            backgroundColor: hasErrors ? AppTheme.warning : AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingServices = false;
          _syncingCategories = false;
          _syncingDescriptions = false;
          _syncingAll = false;
        });
      }
    }
  }

  String _syncLabel(String type) {
    switch (type) {
      case 'services':
        return 'Servis senkronizasyonu';
      case 'categories':
        return 'Kategori senkronizasyonu';
      case 'descriptions':
        return 'Açıklama senkronizasyonu';
      case 'all':
        return 'Tam senkronizasyon';
      default:
        return 'Senkronizasyon';
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  bool _syncHasErrors(Map<String, dynamic> result) {
    final summary = _asMap(result['sync_summary']);
    final errorCount = _asNullableInt(
            summary['errors'] ?? result['errors'] ?? result['error_count']) ??
        0;
    return errorCount > 0;
  }

  String _syncResultText(String type, Map<String, dynamic> result) {
    final summary = _asMap(result['sync_summary']);
    final updated = _asNullableInt(summary['updated']);
    final matched = _asNullableInt(summary['matched']);
    final skipped = _asNullableInt(summary['skipped']);
    final unmatched = _asNullableInt(summary['unmatched']);
    final errors = _asNullableInt(summary['errors']);
    final total = _asNullableInt(summary['total']);

    final parts = <String>[];
    if (updated != null) parts.add('$updated guncellendi');
    if (matched != null) parts.add('$matched eslesti');
    if (skipped != null) parts.add('$skipped atlandi');
    if (unmatched != null && unmatched > 0) parts.add('$unmatched eslesmedi');
    if (errors != null && errors > 0) parts.add('$errors hata');
    if (total != null && parts.isEmpty) parts.add('$total kayit islendi');

    final message = '${summary['message'] ?? result['message'] ?? ''}'.trim();
    final label = _syncLabel(type);

    if (parts.isNotEmpty) return '$label: ${parts.join(' | ')}';
    if (message.isNotEmpty) return '$label: $message';
    return '$label tamamlandi';
  }

  Future<void> _dangerAction(String type) async {
    final isReset = type == 'reset';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String? confirmText;
        return StatefulBuilder(builder: (ctx2, setSt) {
          return AlertDialog(
            backgroundColor: AppTheme.bgCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.error, size: 28),
              const SizedBox(width: 10),
              Text(isReset ? 'Tümünü Sıfırla' : 'Servisleri Sil',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReset
                      ? 'TÜM veriler silinecek: servisler, kategoriler, siparişler. Bu işlem geri alınamaz!'
                      : 'Tüm servisler veritabanından silinecek. Bu işlem geri alınamaz!',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text('Onaylamak için "${isReset ? 'SIFIRLA' : 'SIL'}" yazın:',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                TextField(
                  decoration: AppTheme.inputDecoration(
                      hint: isReset ? 'SIFIRLA' : 'SIL'),
                  onChanged: (v) => setSt(() => confirmText = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('İptal')),
              ElevatedButton(
                onPressed: confirmText == (isReset ? 'SIFIRLA' : 'SIL')
                    ? () => Navigator.pop(ctx, true)
                    : null,
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                child: Text(isReset ? 'Sıfırla' : 'Sil'),
              ),
            ],
          );
        });
      },
    );

    if (confirmed == true) {
      try {
        if (isReset) {
          await AdminApi().resetAll();
        } else {
          await AdminApi().deleteAllServices();
        }
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('İşlem tamamlandı'),
              backgroundColor: AppTheme.success));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));

    return Column(
      children: [
        Container(
          color: AppTheme.bgCard,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primary,
            tabs: const [Tab(text: 'Ayarlar'), Tab(text: 'Error Log')],
            onTap: (i) {
              if (i == 1 && _errorLog.isEmpty) _loadErrorLog();
            },
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [_buildSettingsForm(), _buildErrorLog()],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsForm() {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ═══ API Sistem Ayarları ═══
            _sectionTitle('📡 API Sistem Ayarları'),
            const SizedBox(height: 12),
            _buildSubSection('SMM Panel Bağlantısı', Icons.api_rounded, [
              _buildField('smm_api_url', 'API URL', Icons.link),
              _buildField('smm_api_key', 'API Key', Icons.key),
            ]),
            const SizedBox(height: 12),

            // ═══ SMTP Ayarları ═══
            _buildSubSection('SMTP E-posta Ayarları', Icons.email_rounded, [
              _buildField('smtp_host', 'SMTP Host', Icons.dns),
              _buildField('smtp_port', 'Port', Icons.numbers),
              _buildField('smtp_user', 'Kullanıcı', Icons.person),
              _buildField('smtp_pass', 'Şifre', Icons.lock, obscure: true),
              _buildField(
                  'smtp_from', 'Gönderen E-posta', Icons.alternate_email),
            ]),
            const SizedBox(height: 12),

            // ═══ Fiyatlandırma ═══
            _buildSubSection(
                'Otomatik Fiyatlandırma', Icons.calculate_rounded, [
              _buildBoolField('auto_pricing', 'Otomatik fiyatlandırma'),
              _buildField('price_rate', 'Kur (Çarpan)', Icons.currency_lira),
              _buildPricingPreview(),
            ]),
            const SizedBox(height: 24),

            // ═══ Senkronizasyon ═══
            _sectionTitle('🔄 Veri Senkronizasyonu'),
            const SizedBox(height: 12),
            _buildSyncSection(),
            const SizedBox(height: 24),

            // ═══ Sistem ═══
            _sectionTitle('🔧 Sistem'),
            const SizedBox(height: 12),
            _buildSubSection('Bakım Modu', Icons.construction_rounded, [
              _buildBoolField('maintenance_mode', 'Bakım modunu etkinleştir'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Bakım modu aktifken site ziyaretçilere kapatılır.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.warning))),
                ]),
              ),
            ]),
            const SizedBox(height: 24),

            // ═══ Tehlikeli Bölge ═══
            _sectionTitle('⚠️ Tehlikeli Bölge'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _dangerButton(
                      'Servisleri Sil',
                      'Tüm servisleri veritabanından siler',
                      Icons.delete_sweep_rounded,
                      () => _dangerAction('delete')),
                  const SizedBox(height: 10),
                  _dangerButton(
                      'Tümünü Sıfırla',
                      'Tüm verileri siler ve sistemi sıfırlar',
                      Icons.restart_alt_rounded,
                      () => _dangerAction('reset')),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),

        // ═══ Sticky Save Button ═══
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgDark,
              border: Border(top: BorderSide(color: AppTheme.glassBorder)),
            ),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 20),
              label: Text(_saving ? 'Kaydediliyor...' : 'Bilgileri Kaydet'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700));
  }

  Widget _buildSubSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(String key, String label, IconData icon,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: TextEditingController(text: '${_settings[key] ?? ''}'),
        obscureText: obscure,
        decoration: AppTheme.inputDecoration(
            hint: label, prefixIcon: icon, label: label),
        onChanged: (v) => _settings[key] = v,
      ),
    );
  }

  Widget _buildBoolField(String key, String label) {
    final val =
        _settings[key] == true || _settings[key] == 1 || _settings[key] == '1';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
          Switch(
            value: val,
            onChanged: (v) => setState(() => _settings[key] = v ? 1 : 0),
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingPreview() {
    final rate = double.tryParse('${_settings['price_rate']}') ?? 1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Örnek: 100₺ API fiyatı × $rate kur = ${(100 * rate).toStringAsFixed(2)}₺ satış fiyatı',
            style: const TextStyle(fontSize: 12, color: AppTheme.primary),
          ),
        ),
      ]),
    );
  }

  Widget _buildSyncSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(radius: 16),
      child: Column(
        children: [
          _syncButton('Servisleri Çek', Icons.cloud_download_rounded,
              _syncingServices, () => _runSync('services')),
          const SizedBox(height: 8),
          _syncButton('Kategorileri Çek', Icons.category_rounded,
              _syncingCategories, () => _runSync('categories')),
          const SizedBox(height: 8),
          _syncButton('Açıklamaları Çek', Icons.description_rounded,
              _syncingDescriptions, () => _runSync('descriptions')),
          const Divider(color: AppTheme.glassBorder, height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _syncingAll ? null : () => _runSync('all'),
              icon: _syncingAll
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync_rounded, size: 20),
              label:
                  Text(_syncingAll ? 'Senkronize ediliyor...' : 'Tüm Senkron'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _syncButton(
      String label, IconData icon, bool loading, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textSecondary,
          side: BorderSide(color: AppTheme.glassBorder),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _dangerButton(
      String title, String subtitle, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.error,
          side: BorderSide(color: AppTheme.error.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.error.withValues(alpha: 0.7))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20),
        ]),
      ),
    );
  }

  Widget _buildErrorLog() {
    if (_logLoading)
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    if (_errorLog.isEmpty) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _loadErrorLog,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Error Log Yükle'),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Expanded(
                child: Text('Son 80 satır',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted))),
            IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadErrorLog,
                tooltip: 'Yenile'),
          ]),
        ),
        Expanded(
          child: GlassBox(
            padding: const EdgeInsets.all(12),
            borderRadius: 0,
            child: SingleChildScrollView(
              child: SelectableText(
                _errorLog,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: AppTheme.error,
                    height: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
