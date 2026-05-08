import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/auto_order.dart';
import '../../services/admin_api.dart';
import 'auto_order_create_dialog.dart';
import 'auto_order_detail_sheet.dart';

class AutoOrdersTab extends StatefulWidget {
  const AutoOrdersTab({super.key});

  @override
  State<AutoOrdersTab> createState() => _AutoOrdersTabState();
}

class _AutoOrdersTabState extends State<AutoOrdersTab> {
  final _api = AdminApi();
  final _searchCtrl = TextEditingController();
  final _fmt = NumberFormat('#,##0.00', 'tr_TR');

  List<AutoOrder> _items = const [];
  AutoOrderStats? _stats;
  bool _loading = true;
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  String _status = '';
  String _search = '';

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
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getAutoOrders(
            page: _page, status: _status, search: _search, perPage: 20),
        _api.getAutoOrderStats(),
      ]);
      if (!mounted) return;
      final list = results[0];
      final stats = results[1];
      setState(() {
        _items = ((list['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AutoOrder.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _total = (list['total'] is int)
            ? list['total']
            : int.tryParse('${list['total']}') ?? 0;
        _pages = (list['pages'] is int)
            ? list['pages']
            : int.tryParse('${list['pages']}') ?? 1;
        _stats = AutoOrderStats.fromJson(stats);
        _loading = false;
      });
    } on AuthExpiredException catch (_) {
      _toast('Oturum süresi doldu. Tekrar giriş yapın.', error: true);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Yükleme başarısız: $e', error: true);
    }
  }

  Future<void> _action(AutoOrder ao, String action) async {
    HapticFeedback.lightImpact();
    final confirm = await _confirmDialog(ao, action);
    if (confirm != true) return;
    try {
      await _api.autoOrderAction(ao.id, action);
      if (!mounted) return;
      _toast('İşlem tamamlandı');
      _load();
    } catch (e) {
      _toast('Hata: $e', error: true);
    }
  }

  Future<bool?> _confirmDialog(AutoOrder ao, String action) {
    final labelMap = {
      'pause': ('Duraklat', 'Bu otomatik siparişi duraklatmak istiyor musunuz?'),
      'resume': ('Devam Ettir', 'Otomatik sipariş tekrar başlatılsın mı?'),
      'cancel': (
        'İptal Et',
        'Bu otomatik sipariş iptal edilecek ve kalan bakiye iade edilecek. Devam edilsin mi?'
      ),
      'force_run': ('Hemen Tetikle', 'Sıradaki parti hemen çalıştırılsın mı?'),
      'delete': ('Sil', 'Bu kayıt kalıcı olarak silinsin mi?'),
    };
    final entry = labelMap[action] ?? ('İşlem', 'Devam edilsin mi?');
    final destructive = action == 'cancel' || action == 'delete';

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              destructive
                  ? Icons.error_outline_rounded
                  : Icons.help_outline_rounded,
              color: destructive ? AppTheme.error : AppTheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text('${entry.$1} #${ao.id}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(entry.$2,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    destructive ? AppTheme.error : AppTheme.primary),
            child: Text(entry.$1),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
    ));
  }

  Future<void> _openCreate() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AutoOrderCreateDialog(),
    );
    if (ok == true) _load();
  }

  void _openDetail(AutoOrder ao) {
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AutoOrderDetailSheet(autoOrderId: ao.id),
    ).then((changed) {
      if (changed == true) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stats row
        if (_stats != null) _buildStats(),
        // Toolbar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: AppTheme.inputDecoration(
                  hint: 'Link veya kullanıcı ara...',
                  prefixIcon: Icons.search_rounded,
                ),
                onSubmitted: (v) {
                  _search = v;
                  _page = 1;
                  _load();
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _statusChip('Tümü', '', _status.isEmpty),
                    _statusChip('Aktif', 'active', _status == 'active'),
                    _statusChip('Duraklatıldı', 'paused', _status == 'paused'),
                    _statusChip(
                        'Tamamlandı', 'completed', _status == 'completed'),
                    _statusChip('İptal', 'cancelled', _status == 'cancelled'),
                    _statusChip('Başarısız', 'failed', _status == 'failed'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('$_total kayıt',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Yenile'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: _openCreate,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Yeni'),
                  ),
                ],
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : _items.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppTheme.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _items.length + 1,
                        itemBuilder: (_, i) {
                          if (i == _items.length) return _buildPagination();
                          return _AutoOrderCard(
                            order: _items[i],
                            fmt: _fmt,
                            onTap: () => _openDetail(_items[i]),
                            onPause: () => _action(_items[i], 'pause'),
                            onResume: () => _action(_items[i], 'resume'),
                            onCancel: () => _action(_items[i], 'cancel'),
                            onForceRun: () =>
                                _action(_items[i], 'force_run'),
                            onDelete: () => _action(_items[i], 'delete'),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final s = _stats!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Expanded(
              child: _StatCard(
                  label: 'AKTİF',
                  value: '${s.active}',
                  color: AppTheme.success,
                  icon: Icons.play_arrow_rounded)),
          const SizedBox(width: 8),
          Expanded(
              child: _StatCard(
                  label: 'DURAKLATILDI',
                  value: '${s.paused}',
                  color: AppTheme.warning,
                  icon: Icons.pause_rounded)),
          const SizedBox(width: 8),
          Expanded(
              child: _StatCard(
                  label: 'TAMAMLANDI',
                  value: '${s.completed}',
                  color: AppTheme.info,
                  icon: Icons.check_circle_rounded)),
          const SizedBox(width: 8),
          Expanded(
              child: _StatCard(
                  label: 'KİLİTLİ',
                  value: '₺${_fmt.format(s.totalLocked)}',
                  color: AppTheme.primary,
                  icon: Icons.lock_outline_rounded)),
        ],
      ),
    );
  }

  Widget _statusChip(String label, String value, bool selected) {
    final color =
        value.isEmpty ? AppTheme.primary : _statusColor(value);
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
          border:
              Border.all(color: selected ? color : AppTheme.glassBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? color : AppTheme.textMuted),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return AppTheme.success;
      case 'paused':
        return AppTheme.warning;
      case 'completed':
        return AppTheme.info;
      case 'failed':
        return AppTheme.error;
      case 'cancelled':
        return AppTheme.textMuted;
      default:
        return AppTheme.primary;
    }
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.flash_on_rounded,
            size: 64, color: AppTheme.primary.withValues(alpha: 0.4)),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Otomatik sipariş yok',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Yeni otomatik sipariş eklemek için yukarıdan + butonuna tıklayın.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    if (_pages <= 1) return const SizedBox(height: 30);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _page > 1
                ? () {
                    _page--;
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppTheme.primary,
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$_page / $_pages',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary),
            ),
          ),
          IconButton(
            onPressed: _page < _pages
                ? () {
                    _page++;
                    _load();
                  }
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AutoOrderCard extends StatelessWidget {
  final AutoOrder order;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onForceRun;
  final VoidCallback onDelete;

  const _AutoOrderCard({
    required this.order,
    required this.fmt,
    required this.onTap,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onForceRun,
    required this.onDelete,
  });

  Color get _color {
    switch (order.status) {
      case 'active':
        return AppTheme.success;
      case 'paused':
        return AppTheme.warning;
      case 'completed':
        return AppTheme.info;
      case 'failed':
        return AppTheme.error;
      case 'cancelled':
        return AppTheme.textMuted;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text('#${order.id}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _color)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.serviceName.isEmpty
                            ? 'Servis #${order.serviceId}'
                            : order.serviceName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.userDisplayName.isEmpty
                            ? 'Kullanıcı #${order.userId}'
                            : '${order.userDisplayName}  •  ${order.userEmail}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: _color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    AutoOrder.statusLabel(order.status),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.glassBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded,
                      size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.targetLink,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Progress
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (order.progressPercent / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppTheme.bgInput,
                valueColor: AlwaysStoppedAnimation<Color>(_color),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${order.completedRuns}/${order.totalRuns} parti  •  ${order.completedQuantity}/${order.totalQuantity}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted),
                ),
                const Spacer(),
                Text(
                  '%${order.progressPercent}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _color),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Chip(
                    icon: Icons.timer_outlined,
                    text: _formatInterval(order.runInterval)),
                const SizedBox(width: 6),
                _Chip(
                    icon: Icons.lock_outline,
                    text: '₺${fmt.format(order.lockedBalance)}'),
                const Spacer(),
                if (order.canForceRun)
                  _IconBtn(
                      icon: Icons.flash_on_rounded,
                      color: AppTheme.primary,
                      tooltip: 'Hemen Tetikle',
                      onTap: onForceRun),
                if (order.canPause)
                  _IconBtn(
                      icon: Icons.pause_rounded,
                      color: AppTheme.warning,
                      tooltip: 'Duraklat',
                      onTap: onPause),
                if (order.canResume)
                  _IconBtn(
                      icon: Icons.play_arrow_rounded,
                      color: AppTheme.success,
                      tooltip: 'Devam',
                      onTap: onResume),
                if (order.canCancel)
                  _IconBtn(
                      icon: Icons.cancel_outlined,
                      color: AppTheme.error,
                      tooltip: 'İptal',
                      onTap: onCancel),
                if (order.canDelete)
                  _IconBtn(
                      icon: Icons.delete_outline_rounded,
                      color: AppTheme.error,
                      tooltip: 'Sil',
                      onTap: onDelete),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatInterval(int sec) {
    if (sec >= 86400) return '${(sec / 86400).round()} gün';
    if (sec >= 3600) return '${(sec / 3600).round()} saat';
    return '${(sec / 60).round()} dk';
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgInput,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      ),
    );
  }
}
