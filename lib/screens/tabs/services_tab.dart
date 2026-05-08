import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api.dart';

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});
  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  // ─── Veri ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  bool _syncing = false;
  String _search = '';
  String _activeCategory = '';        // '' = tümü
  bool _selectMode = false;
  final Set<int> _selected = {};
  final _searchCtrl = TextEditingController();

  // ─── Platform renkleri ───────────────────────────────────────────────────
  static const Map<String, Color> _platformColors = {
    'instagram': Color(0xFFE1306C),
    'twitter': Color(0xFF1DA1F2),
    'tiktok': Color(0xFF010101),
    'youtube': Color(0xFFFF0000),
    'facebook': Color(0xFF1877F2),
    'telegram': Color(0xFF2CA5E0),
    'linkedin': Color(0xFF0A66C2),
    'spotify': Color(0xFF1DB954),
    'twitch': Color(0xFF9146FF),
    'discord': Color(0xFF5865F2),
    'snapchat': Color(0xFFFFFC00),
    'pinterest': Color(0xFFE60023),
  };

  Color _colorFor(String name) {
    final key = name.toLowerCase();
    for (final entry in _platformColors.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return AppTheme.primary;
  }

  IconData _iconFor(String name) {
    final key = name.toLowerCase();
    if (key.contains('instagram')) return Icons.camera_alt_rounded;
    if (key.contains('twitter')) return Icons.flutter_dash_rounded;
    if (key.contains('tiktok')) return Icons.music_note_rounded;
    if (key.contains('youtube')) return Icons.play_circle_fill_rounded;
    if (key.contains('facebook')) return Icons.facebook_rounded;
    if (key.contains('telegram')) return Icons.send_rounded;
    if (key.contains('linkedin')) return Icons.business_rounded;
    if (key.contains('spotify')) return Icons.library_music_rounded;
    if (key.contains('twitch')) return Icons.live_tv_rounded;
    if (key.contains('discord')) return Icons.discord_rounded;
    if (key.contains('snapchat')) return Icons.camera_rounded;
    if (key.contains('beğeni') || key.contains('like')) return Icons.favorite_rounded;
    if (key.contains('yorum') || key.contains('comment')) return Icons.comment_rounded;
    if (key.contains('takip') || key.contains('follow')) return Icons.person_add_rounded;
    if (key.contains('izlenme') || key.contains('view')) return Icons.visibility_rounded;
    return Icons.campaign_rounded;
  }

  bool _isActive(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final t = '$v'.trim().toLowerCase();
    return t == '1' || t == 'true' || t == 'yes' || t == 'on' || t == 'active';
  }

  int _svcId(dynamic s) => int.tryParse('${s['id'] ?? ''}') ?? 0;

  // ─── Filtrelenmiş + gruplanmış liste ─────────────────────────────────────
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final q = _search.toLowerCase();
    final filtered = _allItems.where((s) {
      final name = '${s['name_override'] ?? s['name'] ?? ''}'.toLowerCase();
      final cat = '${s['category_name'] ?? s['category'] ?? ''}'.toLowerCase();
      final matchSearch = q.isEmpty || name.contains(q) || cat.contains(q);
      final matchCat = _activeCategory.isEmpty ||
          '${s['category_id'] ?? s['category'] ?? ''}' == _activeCategory ||
          '${s['category_name'] ?? ''}'.toLowerCase() == _activeCategory.toLowerCase();
      return matchSearch && matchCat;
    }).toList();

    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final s in filtered) {
      final cat = '${s['category_name'] ?? s['category'] ?? 'Diğer'}'.trim();
      groups.putIfAbsent(cat, () => []).add(s);
    }
    return groups;
  }

  int get _totalFiltered => _grouped.values.fold(0, (a, b) => a + b.length);

  // ─── Yükleme ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // Tüm servisleri tek seferde çek (büyük per_page)
      final d = await AdminApi().getServices(page: 1, perPage: 500, search: '', category: '');
      final items = (d['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final cats = (d['categories'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _categories = cats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('$e', AppTheme.error);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> svc) async {
    try {
      final cur = _isActive(svc['is_active'] ?? svc['active']);
      await AdminApi().updateService(_svcId(svc), {
        'is_active': cur ? 0 : 1,
        'active': cur ? 0 : 1,
      });
      await _loadAll();
    } catch (e) {
      if (mounted) _showSnack('$e', AppTheme.error);
    }
  }

  Future<void> _syncServices() async {
    setState(() => _syncing = true);
    try {
      await AdminApi().syncServices();
      if (mounted) _showSnack('Senkronizasyon tamamlandı ✅', AppTheme.success);
      await _loadAll();
    } catch (e) {
      if (mounted) _showSnack('$e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _bulkToggle(bool active) async {
    for (final id in _selected) {
      try {
        await AdminApi().updateService(id, {'is_active': active ? 1 : 0, 'active': active ? 1 : 0});
      } catch (_) {}
    }
    setState(() { _selected.clear(); _selectMode = false; });
    await _loadAll();
  }

  void _showEditSheet(Map<String, dynamic> svc) {
    final nameCtrl = TextEditingController(text: '${svc['name_override'] ?? svc['name'] ?? ''}');
    final rateCtrl = TextEditingController(text: '${svc['rate_per_1k'] ?? ''}');
    final minCtrl  = TextEditingController(text: '${svc['min_order'] ?? ''}');
    final maxCtrl  = TextEditingController(text: '${svc['max_order'] ?? ''}');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('#${svc['provider_service_id'] ?? svc['id']}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryLight)),
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Servis Düzenle',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl,
                decoration: AppTheme.inputDecoration(hint: 'Servis Adı', prefixIcon: Icons.label, label: 'Ad')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: rateCtrl, keyboardType: TextInputType.number,
                  decoration: AppTheme.inputDecoration(hint: 'Fiyat/1K', prefixIcon: Icons.attach_money, label: '₺/1K'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: minCtrl, keyboardType: TextInputType.number,
                  decoration: AppTheme.inputDecoration(hint: 'Min', prefixIcon: Icons.arrow_downward, label: 'Min'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: maxCtrl, keyboardType: TextInputType.number,
                  decoration: AppTheme.inputDecoration(hint: 'Max', prefixIcon: Icons.arrow_upward, label: 'Max'))),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await AdminApi().updateService(_svcId(svc), {
                      'name_override': nameCtrl.text.trim(),
                      'rate_per_1k': rateCtrl.text.trim(),
                      'min_order': minCtrl.text.trim(),
                      'max_order': maxCtrl.text.trim(),
                    });
                    if (mounted) _showSnack('Servis güncellendi ✅', AppTheme.success);
                    await _loadAll();
                  } catch (e) {
                    if (mounted) _showSnack('$e', AppTheme.error);
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Kaydet'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  // =========================================================================
  //  BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final categoryNames = grouped.keys.toList()..sort();

    return Column(
      children: [
        // ─── Arama + Aksiyonlar ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: AppTheme.inputDecoration(hint: 'Servis veya kategori ara...', prefixIcon: Icons.search),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: _syncing
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                      : const Icon(Icons.sync_rounded, color: AppTheme.primary, size: 20),
                  tooltip: 'API Sync',
                  onTap: _syncing ? null : _syncServices,
                ),
                const SizedBox(width: 6),
                _actionBtn(
                  icon: Icon(
                    _selectMode ? Icons.close : Icons.checklist_rounded,
                    color: _selectMode ? AppTheme.error : AppTheme.textMuted,
                    size: 20,
                  ),
                  tooltip: 'Toplu İşlem',
                  onTap: () => setState(() { _selectMode = !_selectMode; _selected.clear(); }),
                ),
              ]),
              const SizedBox(height: 8),
              // ─── Kategori chip'leri ───────────────────────────────────
              if (_categories.isNotEmpty)
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _catChip('Tümü', '', _activeCategory.isEmpty),
                      ..._categories.map((c) {
                        final name = '${c['name'] ?? ''}';
                        final color = _colorFor(name);
                        return _catChip(name, '${c['id'] ?? name}',
                            _activeCategory == '${c['id'] ?? name}',
                            color: color);
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              // ─── İstatistik satırı ────────────────────────────────────
              Row(
                children: [
                  Text('$_totalFiltered servis', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(width: 8),
                  Text('• ${categoryNames.length} kategori',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  const Spacer(),
                  if (_loading)
                    const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                ],
              ),
            ],
          ),
        ),

        // ─── Toplu işlem barı ─────────────────────────────────────────────
        if (_selectMode && _selected.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              border: Border(bottom: BorderSide(color: AppTheme.glassBorder)),
            ),
            child: Row(children: [
              Text('${_selected.length} seçili',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _bulkToggle(true),
                icon: const Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                label: const Text('Aktif', style: TextStyle(color: AppTheme.success)),
              ),
              TextButton.icon(
                onPressed: () => _bulkToggle(false),
                icon: const Icon(Icons.cancel, size: 16, color: AppTheme.error),
                label: const Text('Pasif', style: TextStyle(color: AppTheme.error)),
              ),
            ]),
          ),

        // ─── Servis listesi (gruplanmış + bantlı) ─────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : grouped.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadAll,
                      color: AppTheme.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: categoryNames.length,
                        itemBuilder: (_, ci) {
                          final catName = categoryNames[ci];
                          final services = grouped[catName]!;
                          return _buildCategoryGroup(catName, services);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ─── Kategori grubu ───────────────────────────────────────────────────────
  Widget _buildCategoryGroup(String catName, List<Map<String, dynamic>> services) {
    final color = _colorFor(catName);
    final icon = _iconFor(catName);
    final activeCount = services.where((s) => _isActive(s['is_active'] ?? s['active'])).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Kategori başlığı ─────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.08)],
            ),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  catName,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: color, letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$activeCount aktif',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: AppTheme.success)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${services.length} toplam',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
        ),
        // ─── Servis satırları (bantlı) ────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(services.length, (si) {
              final s = services[si];
              final isEven = si % 2 == 0;
              return _buildServiceRow(s, isEven, color, si == services.length - 1);
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceRow(Map<String, dynamic> s, bool isEven, Color catColor, bool isLast) {
    final active = _isActive(s['is_active'] ?? s['active']);
    final id = _svcId(s);
    final isSelected = _selected.contains(id);
    final name = '${s['name_override'] ?? s['name'] ?? '-'}';
    final svcId = '${s['provider_service_id'] ?? s['id'] ?? ''}';
    final rate = double.tryParse('${s['rate_per_1k'] ?? ''}')?.toStringAsFixed(2) ?? '-';
    final min = '${s['min_order'] ?? '-'}';
    final max = '${s['max_order'] ?? '-'}';

    return GestureDetector(
      onTap: _selectMode
          ? () => setState(() { isSelected ? _selected.remove(id) : _selected.add(id); })
          : () => _showEditSheet(s),
      onLongPress: () {
        if (!_selectMode) setState(() { _selectMode = true; _selected.add(id); });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : isEven
                  ? const Color(0xFF0D1526)
                  : const Color(0xFF0A1020),
          border: isLast ? null : const Border(
            bottom: BorderSide(color: Color(0x18FFFFFF)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Checkbox (seçim modu)
            if (_selectMode)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(
                  isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 18, color: AppTheme.primary,
                ),
              ),
            // Aktiflik çizgisi
            Container(
              width: 3, height: 32,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: active ? AppTheme.success : AppTheme.error,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Servis ID badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text('#$svcId',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: catColor)),
            ),
            const SizedBox(width: 10),
            // Servis adı
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500,
                  color: active ? Colors.white : AppTheme.textMuted,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ),
            // Sağ taraf bilgileri
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₺$rate/1K',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryLight)),
                Text('$min–$max',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
            const SizedBox(width: 8),
            // Aktif/Pasif toggle
            if (!_selectMode)
              GestureDetector(
                onTap: () => _toggleActive(s),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.success.withValues(alpha: 0.1)
                        : AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 16, color: active ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Yardımcı widget'lar ──────────────────────────────────────────────────
  Widget _actionBtn({required Widget icon, required String tooltip, VoidCallback? onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1526),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: icon,
        ),
      ),
    );
  }

  Widget _catChip(String label, String value, bool selected, {Color? color}) {
    final c = color ?? AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _activeCategory = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? c.withValues(alpha: 0.2) : const Color(0xFF0D1526),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? c.withValues(alpha: 0.6) : AppTheme.glassBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: selected ? c : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 36, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Servis bulunamadı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Arama kriterlerinizi değiştirmeyi veya API sync yapmayı deneyin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () { _searchCtrl.clear(); setState(() { _search = ''; _activeCategory = ''; }); _loadAll(); },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Sıfırla'),
            ),
          ],
        ),
      ),
    );
  }
}
