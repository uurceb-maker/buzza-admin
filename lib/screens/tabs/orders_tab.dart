import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/admin_api.dart';
import '../../widgets/status_badge.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  List<dynamic> _items = [];
  int _page = 1, _total = 0, _pages = 1;
  bool _loading = true;
  String _status = '';
  String _search = '';
  final _searchCtrl = TextEditingController();
  final _fmt = NumberFormat('#,##0.00', 'tr_TR');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final d = await AdminApi().getOrders(page: _page, status: _status, search: _search);
      if (!mounted) return;
      setState(() {
        _items = d['items'] as List? ?? [];
        _total = d['total'] ?? 0;
        _pages = d['pages'] ?? 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _updateStatus(int id, String newStatus) async {
    try {
      await AdminApi().updateOrderStatus(id, newStatus);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sipariş #$id → ${AppTheme.statusLabel(newStatus)}'),
        backgroundColor: AppTheme.success,
      ));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _cancelOrder(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.cancel_rounded, color: AppTheme.error, size: 24),
          const SizedBox(width: 8),
          Text('Sipariş #$id İptal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: const Text('Bu siparişi iptal etmek istediğinize emin misiniz?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await AdminApi().cancelOrder(id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sipariş #$id iptal edildi'), backgroundColor: AppTheme.success));
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
      }
    }
  }

  void _showStatusDialog(Map<String, dynamic> order) {
    final currentStatus = '${order['status'] ?? 'pending'}';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sipariş #${order['id']} — Durum Güncelle', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Mevcut: ${AppTheme.statusLabel(currentStatus)}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['pending', 'processing', 'completed', 'cancelled', 'partial', 'refunded'].map((s) {
                final selected = s == currentStatus;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    if (!selected) _updateStatus(order['id'], s);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.statusColor(s).withValues(alpha: 0.2) : AppTheme.glassBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? AppTheme.statusColor(s) : AppTheme.glassBorder),
                    ),
                    child: Text(AppTheme.statusLabel(s), style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: selected ? AppTheme.statusColor(s) : AppTheme.textSecondary,
                    )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(Map<String, dynamic> o) {
    final createdAt = '${o['created_at'] ?? '-'}';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Sipariş Detayı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              StatusBadge(status: '${o['status'] ?? 'pending'}', fontSize: 11),
            ]),
            const SizedBox(height: 16),
            _detailRow('Sipariş ID', '#${o['id']}'),
            _detailRow('Kullanıcı', '${o['user_name'] ?? '-'}'),
            _detailRow('Servis', '${o['service_name'] ?? '-'}'),
            _detailRow('Link', '${o['link'] ?? '-'}'),
            _detailRow('Miktar', '${o['quantity'] ?? '-'}'),
            _detailRow('Başlangıç', '${o['start_count'] ?? '-'}'),
            _detailRow('Kalan', '${o['remains'] ?? '-'}'),
            _detailRow('Tutar', '${_fmt.format(double.tryParse('${o['total_price']}') ?? 0)} ₺'),
            _detailRow('Tarih', createdAt),
            const SizedBox(height: 20),

            // Quick action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _cancelOrder(o['id']); },
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label: const Text('İptal Et'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _showStatusDialog(o); },
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Durum Güncelle'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ═══ Search & Filters ═══
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(children: [
            TextField(
              controller: _searchCtrl,
              decoration: AppTheme.inputDecoration(hint: 'Sipariş ID veya kullanıcı ara...', prefixIcon: Icons.search),
              onSubmitted: (v) { _search = v; _page = 1; _load(); },
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _statusChip('Tümü', '', _status.isEmpty),
                  _statusChip('Bekleyen', 'pending', _status == 'pending'),
                  _statusChip('İşleniyor', 'processing', _status == 'processing'),
                  _statusChip('Tamamlandı', 'completed', _status == 'completed'),
                  _statusChip('İptal', 'cancelled', _status == 'cancelled'),
                  _statusChip('Kısmi', 'partial', _status == 'partial'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_total sipariş', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                Text('Sayfa $_page / $_pages', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ]),
        ),

        // ═══ Order List ═══
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

  Widget _statusChip(String label, String value, bool selected) {
    final color = value.isEmpty ? AppTheme.primary : AppTheme.statusColor(value);
    return GestureDetector(
      onTap: () { _status = value; _page = 1; _load(); },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppTheme.glassBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : AppTheme.glassBorder),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? color : AppTheme.textMuted)),
      ),
    );
  }

  Widget _buildItem(dynamic o) {
    final timeAgo = _timeAgo('${o['created_at'] ?? ''}');

    return Dismissible(
      key: ValueKey(o['id']),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          _cancelOrder(o['id']);
          return false;
        } else {
          _showDetailSheet(o);
          return false;
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerLeft,
        child: const Row(children: [Icon(Icons.info_outline, color: AppTheme.info), SizedBox(width: 8), Text('Detaylar', style: TextStyle(color: AppTheme.info, fontWeight: FontWeight.w600))]),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('İptal', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600)), SizedBox(width: 8), Icon(Icons.cancel_rounded, color: AppTheme.error)]),
      ),
      child: GestureDetector(
        onTap: () => _showDetailSheet(o),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.glassDecoration(radius: 14),
          child: Row(
            children: [
              // Status Icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.statusColor('${o['status'] ?? 'pending'}').withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('#${o['id']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.statusColor('${o['status'] ?? 'pending'}'))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text('${o['user_name'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      StatusBadge(status: '${o['status'] ?? 'pending'}', fontSize: 9),
                    ]),
                    const SizedBox(height: 3),
                    Text('${o['service_name'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${_fmt.format(double.tryParse('${o['total_price']}') ?? 0)} ₺', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  if (timeAgo.isNotEmpty) Text(timeAgo, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                ],
              ),
              // Quick action menu
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.textMuted),
                color: AppTheme.bgCard,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'detail', child: Row(children: [Icon(Icons.info_outline, size: 16), SizedBox(width: 8), Text('Detaylar')])),
                  const PopupMenuItem(value: 'status', child: Row(children: [Icon(Icons.sync_rounded, size: 16), SizedBox(width: 8), Text('Durum Güncelle')])),
                  const PopupMenuItem(value: 'cancel', child: Row(children: [Icon(Icons.cancel_rounded, size: 16, color: AppTheme.error), SizedBox(width: 8), Text('İptal Et', style: TextStyle(color: AppTheme.error))])),
                ],
                onSelected: (v) {
                  switch (v) {
                    case 'detail': _showDetailSheet(o); break;
                    case 'status': _showStatusDialog(o); break;
                    case 'cancel': _cancelOrder(o['id']); break;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
      if (diff.inHours < 24) return '${diff.inHours} saat önce';
      return '${diff.inDays} gün önce';
    } catch (_) { return ''; }
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
