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
  List<dynamic> _items = [];
  int _page = 1, _total = 0, _pages = 1;
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();
  final _fmt = NumberFormat('#,##0.00', 'tr_TR');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await AdminApi().getUsers(page: _page, search: _search);
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

  void _showUserDetail(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx2, scrollCtrl) => _UserDetailSheet(user: user, scrollController: scrollCtrl, fmt: _fmt, onUpdate: _load),
      ),
    );
  }

  void _showBalanceDialog(Map<String, dynamic> user) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String type = 'add';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx2).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${user['display_name'] ?? user['email']} — Bakiye', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Mevcut: ${_fmt.format(double.tryParse('${user['balance']}') ?? 0)} ₺', style: const TextStyle(fontSize: 13, color: AppTheme.success, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),

              // Type selector
              Row(children: [
                _typeChip('Ekle', 'add', type == 'add', AppTheme.success, () => setSt(() => type = 'add')),
                const SizedBox(width: 8),
                _typeChip('Çıkar', 'subtract', type == 'subtract', AppTheme.error, () => setSt(() => type = 'subtract')),
                const SizedBox(width: 8),
                _typeChip('Ayarla', 'set', type == 'set', AppTheme.info, () => setSt(() => type = 'set')),
              ]),
              const SizedBox(height: 16),

              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: AppTheme.inputDecoration(hint: 'Miktar (₺)', prefixIcon: Icons.attach_money),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: AppTheme.inputDecoration(hint: 'Açıklama (opsiyonel)', prefixIcon: Icons.note),
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
                      await AdminApi().updateBalance(user['id'], amount, type, descCtrl.text);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bakiye güncellendi ✅'), backgroundColor: AppTheme.success));
                      _load();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
                    }
                  },
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Güncelle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: type == 'subtract' ? AppTheme.error : type == 'set' ? AppTheme.info : AppTheme.success,
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

  Widget _typeChip(String label, String value, bool selected, Color color, VoidCallback onTap) {
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
          child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? color : AppTheme.textMuted))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(children: [
            TextField(
              controller: _searchCtrl,
              decoration: AppTheme.inputDecoration(hint: 'İsim, e-posta veya ID ile ara...', prefixIcon: Icons.search),
              onSubmitted: (v) { _search = v; _page = 1; _load(); },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_total kullanıcı', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                Text('Sayfa $_page / $_pages', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ]),
        ),
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
                      return _buildUserCard(_items[i]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildUserCard(dynamic u) {
    final balance = double.tryParse('${u['balance']}') ?? 0;
    final name = '${u['display_name'] ?? u['email'] ?? '-'}';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _showUserDetail(u),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassDecoration(radius: 14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.accentPink],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(initials, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${u['email'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_fmt.format(balance)} ₺', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: balance > 0 ? AppTheme.success : AppTheme.textMuted)),
                Text('#${u['id']}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.textMuted),
              color: AppTheme.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'detail', child: Row(children: [Icon(Icons.person, size: 16), SizedBox(width: 8), Text('Detaylar')])),
                const PopupMenuItem(value: 'balance', child: Row(children: [Icon(Icons.account_balance_wallet, size: 16), SizedBox(width: 8), Text('Bakiye')])),
                const PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block, size: 16, color: AppTheme.error), SizedBox(width: 8), Text('Engelle', style: TextStyle(color: AppTheme.error))])),
              ],
              onSelected: (v) {
                switch (v) {
                  case 'detail': _showUserDetail(u); break;
                  case 'balance': _showBalanceDialog(u); break;
                  case 'block': _blockUser(u); break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _blockUser(dynamic user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [Icon(Icons.block, color: AppTheme.error, size: 24), SizedBox(width: 8), Text('Kullanıcı Engelle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))]),
        content: Text('${user['display_name'] ?? user['email']} engellenecek. Devam?', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error), child: const Text('Engelle')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await AdminApi().blockUser(user['id']);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı engellendi'), backgroundColor: AppTheme.success));
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
      }
    }
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

// ═══ User Detail Bottom Sheet ═══
class _UserDetailSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final ScrollController scrollController;
  final NumberFormat fmt;
  final VoidCallback onUpdate;

  const _UserDetailSheet({required this.user, required this.scrollController, required this.fmt, required this.onUpdate});

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _orders = [];
  List<dynamic> _logs = [];
  Map<String, dynamic>? _sessions;
  bool _loadingOrders = false, _loadingLogs = false, _loadingSessions = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadOrders() async {
    if (_orders.isNotEmpty) return;
    setState(() => _loadingOrders = true);
    try {
      final d = await AdminApi().getOrders(search: '${widget.user['id']}');
      setState(() { _orders = d['items'] as List? ?? []; _loadingOrders = false; });
    } catch (_) {
      setState(() => _loadingOrders = false);
    }
  }

  Future<void> _loadLogs() async {
    if (_logs.isNotEmpty) return;
    setState(() => _loadingLogs = true);
    try {
      final d = await AdminApi().getUserLogs(widget.user['id']);
      setState(() { _logs = d['items'] as List? ?? []; _loadingLogs = false; });
    } catch (_) {
      setState(() => _loadingLogs = false);
    }
  }

  Future<void> _loadSessions() async {
    if (_sessions != null) return;
    setState(() => _loadingSessions = true);
    try {
      final d = await AdminApi().getUserSessions(widget.user['id']);
      setState(() { _sessions = d; _loadingSessions = false; });
    } catch (_) {
      setState(() => _loadingSessions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final name = '${u['display_name'] ?? u['email'] ?? '-'}';
    final balance = double.tryParse('${u['balance']}') ?? 0;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // ═══ Profile Header ═══
        Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accentPink]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text('${u['email'] ?? '-'}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                Text('ID: ${u['id']} • Kayıt: ${u['registered'] ?? '-'}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // ═══ Balance Card ═══
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.success.withValues(alpha: 0.08), AppTheme.success.withValues(alpha: 0.02)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.15)),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.success, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bakiye', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                Text('${widget.fmt.format(balance)} ₺', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.success)),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ═══ Quick Actions ═══
        Row(children: [
          _actionBtn('Şifre Sıfırla', Icons.lock_reset_rounded, AppTheme.warning, () async {
            try {
              await AdminApi().resetUserPassword(u['id']);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre sıfırlama e-postası gönderildi'), backgroundColor: AppTheme.success));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
            }
          }),
          const SizedBox(width: 8),
          _actionBtn('Engelle', Icons.block_rounded, AppTheme.error, () async {
            Navigator.pop(context);
            try {
              await AdminApi().blockUser(u['id']);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı engellendi'), backgroundColor: AppTheme.success));
              widget.onUpdate();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
            }
          }),
        ]),
        const SizedBox(height: 20),

        // ═══ Tabs ═══
        Container(
          decoration: BoxDecoration(
            color: AppTheme.glassBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabCtrl,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'Siparişler'), Tab(text: 'Loglar'), Tab(text: 'Oturumlar')],
            onTap: (i) {
              if (i == 0) _loadOrders();
              if (i == 1) _loadLogs();
              if (i == 2) _loadSessions();
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: _tabCtrl,
            children: [_buildOrdersTab(), _buildLogsTab(), _buildSessionsTab()],
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_loadingOrders) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_orders.isEmpty) return _emptyState('Sipariş bulunamadı', Icons.shopping_bag_rounded);
    return ListView.builder(
      itemCount: _orders.length,
      itemBuilder: (ctx, i) {
        final o = _orders[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: AppTheme.glassDecoration(radius: 10),
          child: Row(children: [
            Text('#${o['id']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            const SizedBox(width: 8),
            Expanded(child: Text('${o['service_name'] ?? '-'}', style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('${o['status']}', style: TextStyle(fontSize: 10, color: AppTheme.statusColor('${o['status']}'), fontWeight: FontWeight.w600)),
          ]),
        );
      },
    );
  }

  Widget _buildLogsTab() {
    if (_loadingLogs) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_logs.isEmpty) return _emptyState('Log bulunamadı', Icons.history_rounded);
    return ListView.builder(
      itemCount: _logs.length,
      itemBuilder: (ctx, i) {
        final l = _logs[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: AppTheme.glassDecoration(radius: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l['action'] ?? '-'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${l['date'] ?? '-'}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionsTab() {
    if (_loadingSessions) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_sessions == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _loadSessions,
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Oturumları Yükle'),
        ),
      );
    }
    final sessions = (_sessions?['items'] as List?) ?? [];
    if (sessions.isEmpty) return _emptyState('Oturum bulunamadı', Icons.devices_rounded);
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (ctx, i) {
        final s = sessions[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: AppTheme.glassDecoration(radius: 10),
          child: Row(children: [
            const Icon(Icons.computer_rounded, size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${s['ip'] ?? '-'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('${s['browser'] ?? '-'} • ${s['date'] ?? '-'}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _emptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: AppTheme.textMuted),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
