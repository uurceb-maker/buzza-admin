import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api.dart';

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});
  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  List<dynamic> _items = [];
  List<dynamic> _categories = [];
  int _page = 1, _total = 0, _pages = 1;
  bool _loading = true;
  bool _syncing = false;
  String _search = '', _category = '';
  final _searchCtrl = TextEditingController();

  // Multi-select
  bool _selectMode = false;
  final Set<int> _selected = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await AdminApi().getServices(page: _page, search: _search, category: _category);
      setState(() {
        _items = d['items'] as List? ?? [];
        _categories = d['categories'] as List? ?? [];
        _total = d['total'] ?? 0;
        _pages = d['pages'] ?? 1;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> svc) async {
    try {
      await AdminApi().updateService(svc['id'], {'is_active': svc['is_active'] == 1 ? 0 : 1});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _syncServices() async {
    setState(() => _syncing = true);
    try {
      await AdminApi().syncServices();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Senkronizasyon tamamlandı ✅'), backgroundColor: AppTheme.success));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
    setState(() => _syncing = false);
  }

  Future<void> _bulkToggle(bool active) async {
    for (final id in _selected) {
      try {
        await AdminApi().updateService(id, {'is_active': active ? 1 : 0});
      } catch (_) {}
    }
    _selected.clear();
    _selectMode = false;
    _load();
  }

  void _showEditSheet(Map<String, dynamic> svc) {
    final nameCtrl = TextEditingController(text: '${svc['name_override'] ?? svc['name'] ?? ''}');
    final rateCtrl = TextEditingController(text: '${svc['rate_per_1k'] ?? ''}');
    final minCtrl = TextEditingController(text: '${svc['min_order'] ?? ''}');
    final maxCtrl = TextEditingController(text: '${svc['max_order'] ?? ''}');

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
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text('#${svc['provider_service_id'] ?? svc['id']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryLight)),
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Servis Düzenle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: AppTheme.inputDecoration(hint: 'Servis Adı', prefixIcon: Icons.label, label: 'Ad')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: AppTheme.inputDecoration(hint: 'Fiyat/1K', prefixIcon: Icons.attach_money, label: '₺/1K'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: minCtrl, keyboardType: TextInputType.number, decoration: AppTheme.inputDecoration(hint: 'Min', prefixIcon: Icons.arrow_downward, label: 'Min'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: maxCtrl, keyboardType: TextInputType.number, decoration: AppTheme.inputDecoration(hint: 'Max', prefixIcon: Icons.arrow_upward, label: 'Max'))),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await AdminApi().updateService(svc['id'], {
                      'name_override': nameCtrl.text.trim(),
                      'rate_per_1k': rateCtrl.text.trim(),
                      'min_order': minCtrl.text.trim(),
                      'max_order': maxCtrl.text.trim(),
                    });
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servis güncellendi ✅'), backgroundColor: AppTheme.success));
                    _load();
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ═══ Filters & Actions ═══
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: AppTheme.inputDecoration(hint: 'Servis ara...', prefixIcon: Icons.search),
                    onSubmitted: (v) { _search = v; _page = 1; _load(); },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _syncing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                      : const Icon(Icons.sync_rounded, color: AppTheme.primary),
                  onPressed: _syncing ? null : _syncServices,
                  tooltip: 'API Sync',
                ),
                IconButton(
                  icon: Icon(_selectMode ? Icons.close : Icons.checklist_rounded, color: _selectMode ? AppTheme.error : AppTheme.textMuted, size: 20),
                  onPressed: () => setState(() { _selectMode = !_selectMode; _selected.clear(); }),
                  tooltip: 'Toplu İşlem',
                ),
              ]),
              if (_categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chipFilter('Tümü', '', _category.isEmpty),
                      ..._categories.map((c) => _chipFilter('${c['name']}', '${c['id']}', _category == '${c['id']}')),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_total servis', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  Text('Sayfa $_page / $_pages', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        ),

        // ═══ Bulk action bar ═══
        if (_selectMode && _selected.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.bgCard,
            child: Row(children: [
              Text('${_selected.length} seçili', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

        // ═══ Service List ═══
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == _items.length) return _buildPagination();
                      return _buildItem(_items[i]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _chipFilter(String label, String value, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppTheme.textSecondary)),
        selected: selected,
        onSelected: (_) { _category = value; _page = 1; _load(); },
        selectedColor: AppTheme.primary,
        backgroundColor: AppTheme.glassBg,
        side: BorderSide(color: selected ? AppTheme.primary : AppTheme.glassBorder),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildItem(dynamic s) {
    final active = s['is_active'] == 1;
    final isSelected = _selected.contains(s['id']);

    return GestureDetector(
      onTap: _selectMode
          ? () => setState(() { isSelected ? _selected.remove(s['id']) : _selected.add(s['id']); })
          : () => _showEditSheet(s),
      onLongPress: () {
        if (!_selectMode) {
          setState(() { _selectMode = true; _selected.add(s['id']); });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.glassBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (_selectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank, size: 20, color: AppTheme.primary),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text('#${s['provider_service_id'] ?? s['id']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryLight)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: active ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(active ? 'Aktif' : 'Pasif', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? AppTheme.success : AppTheme.error)),
              ),
              const Spacer(),
              if (!_selectMode) ...[
                GestureDetector(
                  onTap: () => _toggleActive(s),
                  child: Icon(active ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 22, color: active ? AppTheme.warning : AppTheme.success),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showEditSheet(s),
                  child: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.textMuted),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Text('${s['name_override'] ?? s['name'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(children: [
              _infoChip('Min: ${s['min_order']}'),
              _infoChip('Max: ${s['max_order']}'),
              _infoChip('₺${double.tryParse('${s['rate_per_1k']}')?.toStringAsFixed(2) ?? '0'}/1K'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppTheme.glassBg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
    );
  }

  Widget _buildPagination() {
    if (_pages <= 1) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: _page > 1 ? () { _page--; _load(); } : null),
          Text('$_page / $_pages', style: const TextStyle(color: AppTheme.textMuted)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: _page < _pages ? () { _page++; _load(); } : null),
        ],
      ),
    );
  }
}
