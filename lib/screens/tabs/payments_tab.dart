import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/admin_api.dart';
import '../../widgets/status_badge.dart';

class PaymentsTab extends StatefulWidget {
  const PaymentsTab({super.key});
  @override
  State<PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<PaymentsTab> {
  List<dynamic> _items = [];
  int _page = 1, _total = 0, _pages = 1;
  bool _loading = true;
  String _status = '';
  final _fmt = NumberFormat('#,##0.00', 'tr_TR');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await AdminApi().getPayments(page: _page, status: _status);
      setState(() {
        _items = d['items'] as List? ?? [];
        _total = d['total'] ?? 0;
        _pages = d['pages'] ?? 1;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _action(int id, String action) async {
    try {
      await AdminApi().paymentAction(id, action);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(action == 'approve' ? 'Ödeme onaylandı ✅' : 'Ödeme reddedildi'),
        backgroundColor: action == 'approve' ? AppTheme.success : AppTheme.error,
      ));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  void _showDetail(Map<String, dynamic> p) {
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
              const Text('Ödeme Detayı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              StatusBadge(status: '${p['status'] ?? 'pending'}', fontSize: 11),
            ]),
            const SizedBox(height: 16),
            _row('ID', '#${p['id']}'),
            _row('Kullanıcı', '${p['user_name'] ?? p['user_email'] ?? '-'}'),
            _row('Tutar', '${_fmt.format(double.tryParse('${p['amount']}') ?? 0)} ₺'),
            _row('Yöntem', '${p['method'] ?? '-'}'),
            _row('Tarih', '${p['created_at'] ?? '-'}'),
            if (p['note'] != null && '${p['note']}'.isNotEmpty)
              _row('Not', '${p['note']}'),
            const SizedBox(height: 20),

            // Approve / Reject buttons
            if ('${p['status']}'.toLowerCase() == 'pending')
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _action(p['id'], 'reject'); },
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reddet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(color: AppTheme.error.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(ctx); _action(p['id'], 'approve'); },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Onayla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ═══ Status Filter ═══
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(children: [
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip('Tümü', '', _status.isEmpty),
                  _chip('Bekleyen', 'pending', _status == 'pending'),
                  _chip('Onaylanan', 'approved', _status == 'approved'),
                  _chip('Reddedilen', 'rejected', _status == 'rejected'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_total ödeme', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                Text('Sayfa $_page / $_pages', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ]),
        ),

        // ═══ Payment List ═══
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: _items.isEmpty
                      ? const Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment_rounded, size: 48, color: AppTheme.textMuted),
                            SizedBox(height: 12),
                            Text('Ödeme bulunamadı', style: TextStyle(color: AppTheme.textMuted)),
                          ],
                        ))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _items.length + 1,
                          itemBuilder: (ctx, i) {
                            if (i == _items.length) return _buildPagination();
                            return _buildPaymentCard(_items[i]);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value, bool selected) {
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

  Widget _buildPaymentCard(dynamic p) {
    final isPending = '${p['status']}'.toLowerCase() == 'pending';
    final amount = double.tryParse('${p['amount']}') ?? 0;

    return Dismissible(
      key: ValueKey(p['id']),
      direction: isPending ? DismissDirection.horizontal : DismissDirection.none,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _action(p['id'], 'approve');
        } else {
          _action(p['id'], 'reject');
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerLeft,
        child: const Row(children: [Icon(Icons.check_rounded, color: AppTheme.success), SizedBox(width: 8), Text('Onayla', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600))]),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('Reddet', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600)), SizedBox(width: 8), Icon(Icons.close_rounded, color: AppTheme.error)]),
      ),
      child: GestureDetector(
        onTap: () => _showDetail(p),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.glassDecoration(radius: 14),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.statusColor('${p['status'] ?? 'pending'}').withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPending ? Icons.hourglass_bottom_rounded : '${p['status']}' == 'approved' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 20,
                  color: AppTheme.statusColor('${p['status'] ?? 'pending'}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text('${p['user_name'] ?? p['user_email'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      StatusBadge(status: '${p['status'] ?? 'pending'}', fontSize: 9),
                    ]),
                    const SizedBox(height: 2),
                    Text('${p['method'] ?? '-'} • ${p['created_at'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${_fmt.format(amount)} ₺', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.success)),

              // Quick approve/reject for pending
              if (isPending) ...[
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.check_circle_rounded, size: 22, color: AppTheme.success), onPressed: () => _action(p['id'], 'approve'), tooltip: 'Onayla', padding: EdgeInsets.zero, constraints: const BoxConstraints(maxWidth: 30)),
                IconButton(icon: const Icon(Icons.cancel_rounded, size: 22, color: AppTheme.error), onPressed: () => _action(p['id'], 'reject'), tooltip: 'Reddet', padding: EdgeInsets.zero, constraints: const BoxConstraints(maxWidth: 30)),
              ],
            ],
          ),
        ),
      ),
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
