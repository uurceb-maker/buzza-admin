import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api.dart';

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});
  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _reorderMode = false;

  bool _isActiveValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '$value'.trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'on' || text == 'active';
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final d = await AdminApi().getCategories();
      final list = (d['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _deleteEmpty() async {
    final count = _items.where((c) => (int.tryParse('${c['service_count']}') ?? 0) == 0).length;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Boş kategori bulunmuyor'), backgroundColor: AppTheme.info));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.delete_sweep_rounded, color: AppTheme.warning, size: 24),
          SizedBox(width: 8),
          Text('Boş Kategorileri Sil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          '$count adet boş kategori (0 servis) silinecek.\nBu işlem geri alınamaz.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AdminApi().deleteEmptyCategories();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Boş kategoriler silindi ✅'), backgroundColor: AppTheme.success));
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
      }
    }
  }

  void _showRenameDialog(Map<String, dynamic> cat) {
    final ctrl = TextEditingController(text: '${cat['name'] ?? ''}');
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
            const Text('Kategori Adını Düzenle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Türkiye pazarına uygun isim girin', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: AppTheme.inputDecoration(hint: 'Kategori adı', prefixIcon: Icons.edit, label: 'Yeni İsim'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (ctrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await AdminApi().updateCategory(cat['id'], {'name': ctrl.text.trim()});
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori güncellendi ✅'), backgroundColor: AppTheme.success));
                    _load();
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleActive(Map<String, dynamic> cat) async {
    final current = _isActiveValue(cat['is_active'] ?? cat['active']);
    try {
      await AdminApi().updateCategory(cat['id'], {
        'active': current ? 0 : 1,
        'is_active': current ? 0 : 1,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(current ? 'Kategori gizlendi' : 'Kategori aktif edildi'),
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
        // ═══ Top Action Bar ═══
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(bottom: BorderSide(color: AppTheme.glassBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_items.length} Kategori',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                ),
              ),
              _actionChip('Boş Sil', Icons.delete_sweep_rounded, AppTheme.warning, _deleteEmpty),
              const SizedBox(width: 8),
              _actionChip(
                _reorderMode ? 'Bitti' : 'Sırala',
                _reorderMode ? Icons.check_rounded : Icons.swap_vert_rounded,
                AppTheme.primary,
                () => setState(() => _reorderMode = !_reorderMode),
              ),
            ],
          ),
        ),

        // ═══ Category List ═══
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: _reorderMode ? _buildReorderList() : _buildNormalList(),
                ),
        ),
      ],
    );
  }

  Widget _buildNormalList() {
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_rounded, size: 48, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('Kategori bulunamadı', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (ctx, i) => _buildCategoryCard(_items[i], i),
    );
  }

  Widget _buildReorderList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _items.removeAt(oldIndex);
          _items.insert(newIndex, item);
        });
        // Save new order to backend
        final ids = _items.map((c) => c['id'] as int).toList();
        AdminApi().reorderCategories(ids).catchError((e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
          return <String, dynamic>{};
        });
      },
      itemBuilder: (ctx, i) => Container(
        key: ValueKey(_items[i]['id']),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassDecoration(radius: 14),
        child: Row(
          children: [
            const Icon(Icons.drag_handle_rounded, size: 20, color: AppTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${_items[i]['name'] ?? '-'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Text('${_items[i]['service_count'] ?? 0} servis', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat, int index) {
    final svcCount = int.tryParse('${cat['service_count']}') ?? 0;
    final isActive = _isActiveValue(cat['is_active'] ?? cat['active']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.glassBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? AppTheme.glassBorder : AppTheme.error.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Index badge
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            ),
          ),
          const SizedBox(width: 12),

          // Name & count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${cat['name'] ?? '-'}',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppTheme.textMuted,
                    decoration: isActive ? null : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 2),
                Row(children: [
                  Text('$svcCount servis', style: TextStyle(
                    fontSize: 11,
                    color: svcCount == 0 ? AppTheme.warning : AppTheme.textMuted,
                    fontWeight: svcCount == 0 ? FontWeight.w600 : FontWeight.w400,
                  )),
                  if (!isActive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Gizli', style: TextStyle(fontSize: 9, color: AppTheme.error, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
              ],
            ),
          ),

          // Actions
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            color: AppTheme.textMuted,
            onPressed: () => _showRenameDialog(cat),
            tooltip: 'Yeniden Adlandır',
          ),
          IconButton(
            icon: Icon(isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18),
            color: isActive ? AppTheme.success : AppTheme.error,
            onPressed: () => _toggleActive(cat),
            tooltip: isActive ? 'Gizle' : 'Göster',
          ),
        ],
      ),
    );
  }

  Widget _actionChip(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}
