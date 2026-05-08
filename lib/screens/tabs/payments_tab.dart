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
  final _dateFmt = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final d = await AdminApi().getPayments(page: _page, status: _status);
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _action(
    int id,
    String action, {
    String reason = '',
  }) async {
    try {
      await AdminApi().paymentAction(id, action, reason: reason);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'approve'
              ? 'Ödeme onaylandı ✅'
              : reason.trim().isEmpty
                  ? 'Ödeme reddedildi'
                  : 'Ödeme reddedildi: $reason'),
          backgroundColor:
              action == 'approve' ? AppTheme.success : AppTheme.error,
        ));
      _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  int? _paymentIdOf(Map<String, dynamic> payment) {
    final raw = payment['id'];
    final parsed = int.tryParse('$raw');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  Future<void> _handleActionLikeTelegram(
    Map<String, dynamic> payment,
    String action,
  ) async {
    final paymentId = _paymentIdOf(payment);
    if (paymentId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Geçersiz ödeme ID'),
          backgroundColor: AppTheme.error,
        ));
      }
      return;
    }

    if (action == 'approve') {
      final approve = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Ödemeyi Onayla'),
              content: Text(
                  '#$paymentId numaralı ödemeyi onaylamak istiyor musunuz?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success),
                  child: const Text('Onayla'),
                ),
              ],
            ),
          ) ??
          false;

      if (!approve) return;
      await _action(paymentId, 'approve');
      return;
    }

    final reason = await _pickRejectReason();
    if (reason == null) return;

    final reject = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ödemeyi Reddet'),
            content: Text('#$paymentId için red sebebi:\n$reason'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                child: const Text('Reddet'),
              ),
            ],
          ),
        ) ??
        false;

    if (!reject) return;
    await _action(paymentId, 'reject', reason: reason);
  }

  Future<String?> _pickRejectReason() async {
    const reasons = <String>[
      'Eksik Dekont',
      'Mükerrer Ödeme',
      'Yanlış Tutar',
      'Diğer',
    ];

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Red Sebebi Seçin',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...reasons.map(
                (reason) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: const Icon(Icons.chevron_right_rounded, size: 18),
                  title: Text(reason, style: const TextStyle(fontSize: 13)),
                  onTap: () => Navigator.pop(ctx, reason),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int? _userIdOf(Map<String, dynamic> payment) {
    final directCandidates = <dynamic>[
      payment['user_id'],
      payment['userId'],
      payment['uid'],
      payment['author_id'],
      payment['author'],
      payment['customer_id'],
    ];
    for (final raw in directCandidates) {
      final parsed = int.tryParse('$raw');
      if (parsed != null && parsed > 0) return parsed;
    }

    final user = payment['user'];
    if (user is Map) {
      final nestedCandidates = <dynamic>[
        user['id'],
        user['user_id'],
        user['ID'],
      ];
      for (final raw in nestedCandidates) {
        final parsed = int.tryParse('$raw');
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return null;
  }

  String _userEmailOf(Map<String, dynamic> payment) {
    final direct = '${payment['user_email'] ?? payment['email'] ?? ''}'.trim();
    if (direct.isNotEmpty) return direct;

    final user = payment['user'];
    if (user is Map) {
      final nested = '${user['email'] ?? user['user_email'] ?? ''}'.trim();
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }

  String _formatDate(dynamic raw) {
    final text = '$raw'.trim();
    if (text.isEmpty || text == '-') return '-';
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return text;
    return _dateFmt.format(parsed.toLocal());
  }

  bool _isSameUser(Map<String, dynamic> item, int? userId, String userEmail) {
    final itemUserId = _userIdOf(item);
    if (userId != null && itemUserId != null) return userId == itemUserId;

    final itemEmail = _userEmailOf(item).toLowerCase();
    if (userEmail.isNotEmpty && itemEmail.isNotEmpty) {
      return userEmail.toLowerCase() == itemEmail;
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> _fetchUserPaymentHistory(
      Map<String, dynamic> payment) async {
    final userId = _userIdOf(payment);
    final userEmail = _userEmailOf(payment);
    if (userId == null && userEmail.isEmpty) return const [];

    final queries = <String>[
      if (userId != null) '$userId',
      if (userEmail.isNotEmpty) userEmail,
    ];

    final collected = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final query in queries) {
      try {
        final data =
            await AdminApi().getPayments(page: 1, search: query, perPage: 25);
        final rawItems = data['items'] as List? ?? const [];

        for (final raw in rawItems) {
          if (raw is! Map) continue;
          final item = Map<String, dynamic>.from(raw);
          if (!_isSameUser(item, userId, userEmail)) continue;

          final key = '${item['id'] ?? item['created_at'] ?? item.hashCode}';
          if (seen.add(key)) collected.add(item);
        }

        if (collected.length >= 8) break;
      } catch (_) {
        // Ignore history endpoint issues; detail sheet should still work.
      }
    }

    collected.sort((a, b) =>
        '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'));
    return collected;
  }

  Future<void> _showBonusDialog(Map<String, dynamic> payment) async {
    final userId = _userIdOf(payment);
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bu ödeme için kullanıcı ID bulunamadı.'),
          backgroundColor: AppTheme.error,
        ));
      }
      return;
    }

    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController(
      text: 'Ödeme #${payment['id']} sonrası bonus',
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bonus / Bakiye Ekle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${payment['user_name'] ?? payment['user_email'] ?? '-'}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: AppTheme.inputDecoration(
                hint: 'Bonus miktarı (₺)',
                prefixIcon: Icons.add_card_rounded,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: AppTheme.inputDecoration(
                hint: 'Açıklama (opsiyonel)',
                prefixIcon: Icons.note_alt_outlined,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text);
                  if (amount == null || amount <= 0) return;
                  Navigator.pop(ctx);
                  try {
                    final result = await AdminApi()
                        .updateBalance(userId, amount, 'add', descCtrl.text);
                    if (mounted) {
                      final before = result['balance_before'] ?? '?';
                      final after = result['balance_after'] ?? '?';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            '+${_fmt.format(amount)} ₺ bonus eklendi ✅\nBakiye: $before → $after ₺'),
                        backgroundColor: AppTheme.success,
                        duration: const Duration(seconds: 3),
                      ));
                    }
                    _load();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$e'),
                        backgroundColor: AppTheme.error,
                      ));
                    }
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Kaydet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _showBalanceEditDialog(Map<String, dynamic> payment) async {
    final userId = _userIdOf(payment);
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kullanici ID bulunamadi.'),
          backgroundColor: AppTheme.error,
        ));
      }
      return;
    }

    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: 'Yonetici bakiye duzenlemesi');
    String actionType = 'add';

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx2).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.account_balance_wallet_rounded,
                    size: 20, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Bakiye Duzenle',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
              Text('${payment['user_name'] ?? payment['user_email'] ?? '-'} (ID: $userId)',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setSheetState(() => actionType = 'add'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: actionType == 'add'
                            ? AppTheme.success.withValues(alpha: 0.15)
                            : AppTheme.glassBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: actionType == 'add'
                                ? AppTheme.success
                                : AppTheme.glassBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 18,
                              color: actionType == 'add' ? AppTheme.success : AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text('Ekle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: actionType == 'add' ? AppTheme.success : AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setSheetState(() => actionType = 'deduct'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: actionType == 'deduct'
                            ? AppTheme.error.withValues(alpha: 0.15)
                            : AppTheme.glassBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: actionType == 'deduct'
                                ? AppTheme.error
                                : AppTheme.glassBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.remove_rounded, size: 18,
                              color: actionType == 'deduct' ? AppTheme.error : AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text('Dus', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: actionType == 'deduct' ? AppTheme.error : AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: AppTheme.inputDecoration(
                  hint: 'Tutar (TL)',
                  prefixIcon: actionType == 'add' ? Icons.add_card_rounded : Icons.money_off_rounded,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: AppTheme.inputDecoration(
                  hint: 'Aciklama',
                  prefixIcon: Icons.note_alt_outlined,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text);
                    if (amount == null || amount <= 0) return;
                    Navigator.pop(ctx);
                    try {
                      final result = await AdminApi()
                          .updateBalance(userId, amount, actionType, descCtrl.text);
                      if (mounted) {
                        final before = result['balance_before'] ?? '?';
                        final after = result['balance_after'] ?? '?';
                        final sign = actionType == 'add' ? '+' : '-';
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              '$sign${_fmt.format(amount)} TL ${actionType == 'add' ? 'eklendi' : 'dusuldu'}\nBakiye: $before -> $after TL'),
                          backgroundColor: actionType == 'add' ? AppTheme.success : AppTheme.warning,
                          duration: const Duration(seconds: 3),
                        ));
                      }
                      _load();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('$e'), backgroundColor: AppTheme.error));
                      }
                    }
                  },
                  icon: Icon(actionType == 'add' ? Icons.save_rounded : Icons.remove_circle_outline, size: 18),
                  label: Text(actionType == 'add' ? 'Bakiye Ekle' : 'Bakiye Dus'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionType == 'add' ? AppTheme.success : AppTheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _showDetail(Map<String, dynamic> p) {
    final historyFuture = _fetchUserPaymentHistory(p);
    final userId = _userIdOf(p);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.95,
        minChildSize: 0.45,
        builder: (ctx2, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('Ödeme Detayı',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                StatusBadge(
                    status: '${p['status'] ?? 'pending'}', fontSize: 11),
              ]),
              const SizedBox(height: 16),
              _row('ID', '#${p['id']}'),
              if (userId != null) _row('Kullanıcı ID', '#$userId'),
              _row('Kullanıcı', '${p['user_name'] ?? p['user_email'] ?? '-'}'),
              _row('Tutar',
                  '${_fmt.format(double.tryParse('${p['amount']}') ?? 0)} ₺'),
              _row('Yöntem', '${p['method'] ?? '-'}'),
              _row('Tarih', _formatDate(p['created_at'])),
              if (p['reference'] != null && '${p['reference']}'.isNotEmpty)
                _row('Referans', '${p['reference']}'),
              if (p['note'] != null && '${p['note']}'.isNotEmpty)
                _row('Not', '${p['note']}'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: userId == null ? null : () => _showBonusDialog(p),
                    icon: const Icon(Icons.add_card_rounded, size: 16),
                    label: const Text('Bonus'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.success,
                  side: BorderSide(
                      color: AppTheme.success.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: userId == null ? null : () => _showBalanceEditDialog(p),
                    icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                    label: const Text('Bakiye'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              // Balance log history
              if (userId != null) ...[
                const Text('Bakiye Geçmişi',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                FutureBuilder<Map<String, dynamic>>(
                  future: AdminApi().getBalanceLogs(userId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
                    }
                    final items = (snap.data?['items'] as List?) ?? [];
                    if (items.isEmpty) {
                      return Container(
                        width: double.infinity, padding: const EdgeInsets.all(12),
                        decoration: AppTheme.glassDecoration(radius: 12),
                        child: const Text('Bakiye geçmişi bulunamadı.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)));
                    }
                    return Column(children: items.take(6).map((item) {
                      final type = '${item['type'] ?? ''}';
                      final isAdd = type.contains('add') || type.contains('payment') || type.contains('approve');
                      final amt = double.tryParse('${item['amount']}') ?? 0;
                      final desc = '${item['description'] ?? '-'}';
                      final date = _formatDate(item['created_at']);
                      final before = item['balance_before'] ?? '?';
                      final after = item['balance_after'] ?? '?';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: AppTheme.glassDecoration(radius: 12),
                        child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: (isAdd ? AppTheme.success : AppTheme.error).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8)),
                            child: Icon(isAdd ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                size: 18, color: isAdd ? AppTheme.success : AppTheme.error)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(desc, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('$date  •  $before → $after TL', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                          ])),
                          Text('${isAdd ? '+' : '-'}${_fmt.format(amt)} ₺',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: isAdd ? AppTheme.success : AppTheme.error)),
                        ]));
                    }).toList());
                  },
                ),
                const SizedBox(height: 18),
              ],
              const Text(
                'Kullanıcının Geçmiş Ödemeleri',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: historyFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  final history = snap.data ?? const <Map<String, dynamic>>[];
                  if (history.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: AppTheme.glassDecoration(radius: 12),
                      child: const Text(
                        'Bu kullanıcı için geçmiş ödeme bulunamadı.',
                        style:
                            TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    );
                  }

                  final visible = history.take(6).toList();
                  return Column(
                    children: [
                      ...visible.map((item) {
                        final status = '${item['status'] ?? 'pending'}';
                        final amount =
                            double.tryParse('${item['amount']}') ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: AppTheme.glassDecoration(radius: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '#${item['id'] ?? '-'} • ${item['method'] ?? '-'}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(item['created_at']),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${_fmt.format(amount)} ₺',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  StatusBadge(status: status, fontSize: 9),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      if (history.length > visible.length)
                        Text(
                          '+${history.length - visible.length} ödeme daha',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              if ('${p['status']}'.toLowerCase() == 'pending')
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleActionLikeTelegram(p, 'reject');
                      },
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text('Reddet #${p['id']}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: BorderSide(
                            color: AppTheme.error.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleActionLikeTelegram(p, 'approve');
                      },
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text('Onayla #${p['id']}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              const SizedBox(height: 8),
            ],
          ),
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
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textMuted))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
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
                Text('$_total ödeme',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
                Text('Sayfa $_page / $_pages',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ]),
        ),

        // ═══ Payment List ═══
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: _items.isEmpty
                      ? const Center(
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment_rounded,
                                size: 48, color: AppTheme.textMuted),
                            SizedBox(height: 12),
                            Text('Ödeme bulunamadı',
                                style: TextStyle(color: AppTheme.textMuted)),
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
    final color =
        value.isEmpty ? AppTheme.primary : AppTheme.statusColor(value);
    return GestureDetector(
      onTap: () {
        _status = value;
        _page = 1;
        _load();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppTheme.glassBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color : AppTheme.glassBorder),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppTheme.textMuted)),
      ),
    );
  }

  Widget _buildPaymentCard(dynamic p) {
    final payment =
        p is Map<String, dynamic> ? p : Map<String, dynamic>.from(p as Map);
    final isPending = '${p['status']}'.toLowerCase() == 'pending';
    final amount = double.tryParse('${p['amount']}') ?? 0;

    return Dismissible(
      key: ValueKey(p['id']),
      direction:
          isPending ? DismissDirection.horizontal : DismissDirection.none,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _handleActionLikeTelegram(payment, 'approve');
        } else {
          _handleActionLikeTelegram(payment, 'reject');
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerLeft,
        child: const Row(children: [
          Icon(Icons.check_rounded, color: AppTheme.success),
          SizedBox(width: 8),
          Text('Onayla',
              style: TextStyle(
                  color: AppTheme.success, fontWeight: FontWeight.w600))
        ]),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('Reddet',
              style: TextStyle(
                  color: AppTheme.error, fontWeight: FontWeight.w600)),
          SizedBox(width: 8),
          Icon(Icons.close_rounded, color: AppTheme.error)
        ]),
      ),
      child: GestureDetector(
        onTap: () => _showDetail(payment),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.glassDecoration(radius: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.statusColor('${p['status'] ?? 'pending'}')
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPending
                      ? Icons.hourglass_bottom_rounded
                      : '${p['status']}' == 'approved'
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
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
                      Expanded(
                          child: Text(
                              '${p['user_name'] ?? p['user_email'] ?? '-'}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis)),
                      StatusBadge(
                          status: '${p['status'] ?? 'pending'}', fontSize: 9),
                    ]),
                    const SizedBox(height: 2),
                    Text('${p['method'] ?? '-'} • ${p['created_at'] ?? '-'}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('${_fmt.format(amount)} ₺',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success)),

              // Quick approve/reject for pending
              if (isPending) ...[
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                      icon: const Icon(Icons.check_circle_rounded,
                          size: 24, color: AppTheme.success),
                      onPressed: () =>
                          _handleActionLikeTelegram(payment, 'approve'),
                      tooltip: 'Onayla',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints()),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                      icon: const Icon(Icons.cancel_rounded,
                          size: 24, color: AppTheme.error),
                      onPressed: () =>
                          _handleActionLikeTelegram(payment, 'reject'),
                      tooltip: 'Reddet',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints()),
                ),
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
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _page > 1
                  ? () {
                      _page--;
                      _load();
                    }
                  : null),
          Text('$_page / $_pages',
              style: const TextStyle(color: AppTheme.textMuted)),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _page < _pages
                  ? () {
                      _page++;
                      _load();
                    }
                  : null),
        ],
      ),
    );
  }
}
