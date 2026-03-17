import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/admin_api.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final NumberFormat _moneyFmt = NumberFormat('#,##0.00', 'tr_TR');

  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  bool _loading = true;
  String _search = '';

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await AdminApi().getUsers(page: _page, search: _search);
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _page = _asInt(data['page'], fallback: _page);
        _pages = _asInt(data['pages'], fallback: 1);
        _total = _asInt(data['total'], fallback: _items.length);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _openUserDetail(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _UserInsightSheet(
          user: user,
          moneyFmt: _moneyFmt,
          onRefreshParent: _load,
        ),
      ),
    );
  }

  Future<void> _showBalanceDialog(Map<String, dynamic> user) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var type = 'add';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx2).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${user['display_name'] ?? user['email'] ?? '-'} - Bakiye',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _chip('Ekle', type == 'add', AppTheme.success,
                      () => setSt(() => type = 'add')),
                  const SizedBox(width: 8),
                  _chip('Cikar', type == 'subtract', AppTheme.error,
                      () => setSt(() => type = 'subtract')),
                  const SizedBox(width: 8),
                  _chip('Ayarla', type == 'set', AppTheme.info,
                      () => setSt(() => type = 'set')),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: AppTheme.inputDecoration(
                      hint: 'Miktar',
                      label: 'Bakiye miktari',
                      prefixIcon: Icons.currency_lira_rounded)),
              const SizedBox(height: 10),
              TextField(
                  controller: descCtrl,
                  decoration: AppTheme.inputDecoration(
                      hint: 'Not',
                      label: 'Aciklama',
                      prefixIcon: Icons.notes_rounded)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text.trim());
                    if (amount == null || amount <= 0) return;
                    Navigator.pop(ctx);
                    try {
                      await AdminApi().updateBalance(_asInt(user['id']), amount,
                          type, descCtrl.text.trim());
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Bakiye guncellendi'),
                          backgroundColor: AppTheme.success));
                      _load();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('$e'),
                          backgroundColor: AppTheme.error));
                    }
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : AppTheme.glassBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : AppTheme.glassBorder),
          ),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? color : AppTheme.textMuted))),
        ),
      ),
    );
  }

  Future<void> _blockUser(Map<String, dynamic> user) async {
    try {
      await AdminApi().blockUser(_asInt(user['id']));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kullanici engellendi'),
          backgroundColor: AppTheme.success));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: AppTheme.inputDecoration(
                    hint: 'Isim, e-posta veya ID',
                    label: 'Kullanici ara',
                    prefixIcon: Icons.search_rounded),
                onSubmitted: (value) {
                  _search = value.trim();
                  _page = 1;
                  _load();
                },
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('$_total kullanici',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
                Text('Sayfa $_page / $_pages',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
              ]),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _items.length) return _pagination();
                      final user = _items[index];
                      final name =
                          '${user['display_name'] ?? user['email'] ?? '-'}';
                      final email = '${user['email'] ?? '-'}';
                      final id = _asInt(user['id']);
                      final balance = _asDouble(user['balance']);
                      final initials = name.trim().isNotEmpty
                          ? name.trim().substring(0, 1).toUpperCase()
                          : '?';
                      return GestureDetector(
                        onTap: () => _openUserDetail(user),
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
                                  gradient: const LinearGradient(
                                      colors: [
                                        AppTheme.primary,
                                        AppTheme.accentPink
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                    child: Text(initials,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textMuted)),
                                    ]),
                              ),
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${_moneyFmt.format(balance)} TL',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: balance > 0
                                                ? AppTheme.success
                                                : AppTheme.textMuted)),
                                    Text('#$id',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textMuted)),
                                  ]),
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded,
                                    size: 18, color: AppTheme.textMuted),
                                color: AppTheme.bgCard,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'detail', child: Text('Detay')),
                                  PopupMenuItem(
                                      value: 'balance', child: Text('Bakiye')),
                                  PopupMenuItem(
                                      value: 'block', child: Text('Engelle')),
                                ],
                                onSelected: (value) {
                                  if (value == 'detail') {
                                    _openUserDetail(user);
                                  }
                                  if (value == 'balance') {
                                    _showBalanceDialog(user);
                                  }
                                  if (value == 'block') {
                                    _blockUser(user);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _pagination() {
    if (_pages <= 1) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          onPressed: _page > 1
              ? () {
                  setState(() => _page--);
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text('$_page / $_pages',
            style: const TextStyle(color: AppTheme.textMuted)),
        IconButton(
          onPressed: _page < _pages
              ? () {
                  setState(() => _page++);
                  _load();
                }
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ]),
    );
  }
}

class _UserInsightSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final NumberFormat moneyFmt;
  final VoidCallback onRefreshParent;

  const _UserInsightSheet(
      {required this.user,
      required this.moneyFmt,
      required this.onRefreshParent});

  @override
  State<_UserInsightSheet> createState() => _UserInsightSheetState();
}

class _UserInsightSheetState extends State<_UserInsightSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = true;

  Map<String, dynamic> _user = {};
  Map<String, dynamic> _metrics = {};
  Map<String, dynamic> _security = {};
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _topServices = [];
  List<Map<String, dynamic>> _ipSummary = [];
  List<Map<String, dynamic>> _timeline = [];

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse('$value') ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await AdminApi().getUser360(_asInt(widget.user['id']));
      if (!mounted) return;
      final merged = Map<String, dynamic>.from(widget.user)
        ..addAll((data['user'] as Map?)?.cast<String, dynamic>() ?? {});
      setState(() {
        _user = merged;
        _metrics = Map<String, dynamic>.from((data['metrics'] as Map?) ?? {});
        _security = Map<String, dynamic>.from((data['security'] as Map?) ?? {});
        _orders = (data['orders'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _logs = (data['logs'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _topServices = (data['top_services'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _ipSummary = (data['ip_summary'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _timeline = (data['timeline'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Color _riskColor(int score) {
    if (score >= 70) return AppTheme.error;
    if (score >= 40) return AppTheme.warning;
    return AppTheme.success;
  }

  Widget _empty(String text, IconData icon) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 34, color: AppTheme.textMuted),
      const SizedBox(height: 8),
      Text(text, style: const TextStyle(color: AppTheme.textMuted))
    ]));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }

    final name = '${_user['display_name'] ?? _user['email'] ?? '-'}';
    final email = '${_user['email'] ?? '-'}';
    final id = _asInt(_user['id']);
    final risk = _asInt(_metrics['risk_score']);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(email,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted)),
                  Text('ID: $id',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textSecondary))
                ])),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: _riskColor(risk).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999)),
                child: Text('Risk $risk',
                    style: TextStyle(
                        color: _riskColor(risk),
                        fontSize: 11,
                        fontWeight: FontWeight.w700))),
          ]),
        ),
        Container(
          color: AppTheme.bgCard,
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primary,
            tabs: const [
              Tab(text: 'Ozet'),
              Tab(text: 'Siparisler'),
              Tab(text: 'Servisler'),
              Tab(text: 'Aktivite'),
              Tab(text: 'Guvenlik'),
              Tab(text: 'Timeline'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              ListView(padding: const EdgeInsets.all(12), children: [
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _mCard(
                      'Toplam Siparis',
                      '${_asInt(_metrics['total_orders'], fallback: _orders.length)}',
                      Icons.receipt_long_rounded,
                      AppTheme.info),
                  _mCard(
                      'Toplam Harcama',
                      '${widget.moneyFmt.format(_asDouble(_metrics['total_spent']))} TL',
                      Icons.attach_money_rounded,
                      AppTheme.success),
                  _mCard(
                      'Benzersiz IP',
                      '${_asInt(_metrics['unique_ips'], fallback: _ipSummary.length)}',
                      Icons.language_rounded,
                      AppTheme.warning),
                  _mCard(
                      'Failed Login',
                      '${_asInt(_security['failed_logins'])}',
                      Icons.key_off_rounded,
                      AppTheme.error),
                ]),
              ]),
              _orders.isEmpty
                  ? _empty('Siparis bulunamadi', Icons.receipt_long_rounded)
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _orders.length,
                      itemBuilder: (_, i) {
                        final o = _orders[i];
                        return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: AppTheme.glassDecoration(radius: 12),
                            child: Text(
                                '#${o['id']}  ${o['service_name']}  ${o['status']}  ${widget.moneyFmt.format(_asDouble(o['amount']))} TL',
                                style: const TextStyle(fontSize: 11)));
                      },
                    ),
              _topServices.isEmpty
                  ? _empty('Servis kullanim verisi yok',
                      Icons.design_services_rounded)
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _topServices.length,
                      itemBuilder: (_, i) {
                        final s = _topServices[i];
                        return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: AppTheme.glassDecoration(radius: 12),
                            child: Text(
                                '${i + 1}. ${s['service_name']}  -  ${s['count']} adet  -  ${widget.moneyFmt.format(_asDouble(s['total_amount']))} TL',
                                style: const TextStyle(fontSize: 11)));
                      },
                    ),
              _logs.isEmpty
                  ? _empty('Aktivite logu yok', Icons.history_rounded)
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _logs.length,
                      itemBuilder: (_, i) {
                        final l = _logs[i];
                        return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: AppTheme.glassDecoration(radius: 12),
                            child: Text(
                                '${l['date']}  ${l['action']}\n${l['message']}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)));
                      },
                    ),
              ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: AppTheme.glassDecoration(radius: 12),
                      child: Text(
                          'Failed login: ${_asInt(_security['failed_logins'])}  |  Block sinyali: ${_asInt(_security['blocked_signals'])}  |  Benzersiz IP: ${_asInt(_security['unique_ips'], fallback: _ipSummary.length)}',
                          style: const TextStyle(fontSize: 11))),
                  const SizedBox(height: 8),
                  if (_ipSummary.isEmpty)
                    const Text('IP gecmisi yok',
                        style: TextStyle(color: AppTheme.textMuted))
                  else
                    ..._ipSummary.map((ip) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: AppTheme.glassDecoration(radius: 12),
                        child: Text(
                            '${ip['ip']}  -  ${ip['count']} kez  -  Son: ${ip['last_seen']}',
                            style: const TextStyle(fontSize: 11)))),
                ],
              ),
              _timeline.isEmpty
                  ? _empty('Timeline yok', Icons.timeline_rounded)
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _timeline.length,
                      itemBuilder: (_, i) {
                        final t = _timeline[i];
                        return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: AppTheme.glassDecoration(radius: 12),
                            child: Text(
                                '${t['date']}  ${t['title']}\n${t['message']}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)));
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mCard(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 158,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.glassDecoration(radius: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ]),
      ),
    );
  }
}
