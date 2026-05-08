import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/auto_order.dart';
import '../../services/admin_api.dart';

class AutoOrderDetailSheet extends StatefulWidget {
  final int autoOrderId;
  const AutoOrderDetailSheet({super.key, required this.autoOrderId});

  @override
  State<AutoOrderDetailSheet> createState() =>
      _AutoOrderDetailSheetState();
}

class _AutoOrderDetailSheetState extends State<AutoOrderDetailSheet> {
  final _api = AdminApi();
  final _fmt = NumberFormat('#,##0.00', 'tr_TR');

  AutoOrder? _order;
  List<AutoOrderRun> _runs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _api.getAutoOrderDetail(widget.autoOrderId);
      if (!mounted) return;
      setState(() {
        _order = result['order'] is Map
            ? AutoOrder.fromJson(Map<String, dynamic>.from(result['order']))
            : null;
        _runs = ((result['runs'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) =>
                AutoOrderRun.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  Future<void> _action(String action) async {
    HapticFeedback.lightImpact();
    try {
      await _api.autoOrderAction(widget.autoOrderId, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('İşlem tamamlandı'),
        backgroundColor: AppTheme.success,
      ));
      if (action == 'delete') {
        Navigator.pop(context, true);
      } else {
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  Color _color(String s) {
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary))
                    : _order == null
                        ? const Center(child: Text('Bulunamadı.'))
                        : ListView(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(
                                16, 14, 16, 30),
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 14),
                              _buildProgress(),
                              const SizedBox(height: 14),
                              _buildBalance(),
                              const SizedBox(height: 14),
                              _buildInfo(),
                              const SizedBox(height: 14),
                              _buildActionsRow(),
                              const SizedBox(height: 16),
                              _buildRunsList(),
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final o = _order!;
    final c = _color(o.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.18), c.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.flash_on_rounded, color: c, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Otomatik Sipariş #${o.id}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      o.serviceName.isEmpty
                          ? 'Servis #${o.serviceId}'
                          : o.serviceName,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: c.withValues(alpha: 0.35)),
                ),
                child: Text(
                  AutoOrder.statusLabel(o.status),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.glassBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    o.userDisplayName.isEmpty
                        ? 'Kullanıcı #${o.userId}'
                        : '${o.userDisplayName}  •  ${o.userEmail}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.glassBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(o.targetLink,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final o = _order!;
    final c = _color(o.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('İlerleme',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              Text('%${o.progressPercent}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: c)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (o.progressPercent / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.bgInput,
              valueColor: AlwaysStoppedAnimation<Color>(c),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _kv('Tamamlanan parti',
                    '${o.completedRuns}/${o.totalRuns}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kv('Tamamlanan adet',
                    '${o.completedQuantity}/${o.totalQuantity}'),
              ),
            ],
          ),
          if (o.failedRuns > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.error, size: 14),
                const SizedBox(width: 6),
                Text('${o.failedRuns} başarısız parti',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.error)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalance() {
    final o = _order!;
    final remaining =
        (o.lockedBalance - o.spentBalance - o.refundedBalance)
            .clamp(0, double.infinity);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        children: [
          _row(Icons.lock_outline_rounded, 'Kilitli',
              '₺${_fmt.format(o.lockedBalance)}'),
          const SizedBox(height: 6),
          _row(Icons.shopping_bag_outlined, 'Harcanan',
              '₺${_fmt.format(o.spentBalance)}'),
          const SizedBox(height: 6),
          _row(Icons.replay_rounded, 'İade',
              '₺${_fmt.format(o.refundedBalance)}'),
          const Divider(height: 18, color: AppTheme.glassBorder),
          _row(Icons.account_balance_wallet_rounded, 'Kalan',
              '₺${_fmt.format(remaining)}',
              bold: true),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    final o = _order!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        children: [
          _row(Icons.timer_outlined, 'Tekrar aralığı',
              _formatInterval(o.runInterval)),
          const SizedBox(height: 6),
          _row(Icons.payments_outlined, 'Birim fiyat',
              '₺${_fmt.format(o.ratePer1k)} / 1k'),
          const SizedBox(height: 6),
          _row(Icons.calendar_today_rounded, 'Oluşturulma',
              o.createdAt ?? '-'),
          const SizedBox(height: 6),
          _row(Icons.event_available_rounded, 'Sıradaki',
              o.nextRunAt ?? '-'),
          const SizedBox(height: 6),
          _row(Icons.history_rounded, 'Son tetikleme',
              o.lastRunAt ?? '-'),
          const SizedBox(height: 6),
          _row(Icons.badge_outlined, 'Oluşturan', o.createdBy),
        ],
      ),
    );
  }

  Widget _buildActionsRow() {
    final o = _order!;
    final actions = <Widget>[];

    if (o.canForceRun) {
      actions.add(_actionBtn(Icons.flash_on_rounded, 'Hemen Tetikle',
          AppTheme.primary, () => _action('force_run')));
    }
    if (o.canPause) {
      actions.add(_actionBtn(Icons.pause_rounded, 'Duraklat',
          AppTheme.warning, () => _action('pause')));
    }
    if (o.canResume) {
      actions.add(_actionBtn(Icons.play_arrow_rounded, 'Devam',
          AppTheme.success, () => _action('resume')));
    }
    if (o.canCancel) {
      actions.add(_actionBtn(Icons.cancel_outlined, 'İptal',
          AppTheme.error, () => _action('cancel')));
    }
    if (o.canDelete) {
      actions.add(_actionBtn(Icons.delete_outline_rounded, 'Sil',
          AppTheme.error, () => _action('delete')));
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 130,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildRunsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Tetikleme Geçmişi (${_runs.length})',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary),
          ),
        ),
        if (_runs.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: const Text(
              'Henüz tetikleme yok.',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textMuted),
            ),
          )
        else
          ..._runs.map((r) => _RunRow(run: r, fmt: _fmt)),
      ],
    );
  }

  Widget _row(IconData icon, String label, String value,
      {bool bold = false}) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11.5, color: AppTheme.textMuted)),
        const Spacer(),
        Text(value,
            style: TextStyle(
              fontSize: bold ? 13 : 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: AppTheme.textPrimary,
            )),
      ],
    );
  }

  Widget _kv(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgInput,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  static String _formatInterval(int sec) {
    if (sec >= 86400) return '${(sec / 86400).round()} gün';
    if (sec >= 3600) return '${(sec / 3600).round()} saat';
    return '${(sec / 60).round()} dakika';
  }
}

class _RunRow extends StatelessWidget {
  final AutoOrderRun run;
  final NumberFormat fmt;
  const _RunRow({required this.run, required this.fmt});

  Color get _color {
    switch (run.status) {
      case 'completed':
        return AppTheme.success;
      case 'processing':
        return AppTheme.info;
      case 'failed':
        return AppTheme.error;
      case 'skipped':
        return AppTheme.textMuted;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text('#${run.runNumber}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _color,
                )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${run.quantity} adet • ₺${fmt.format(run.totalPrice)}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary),
                ),
                Text(
                  run.completedAt ??
                      run.startedAt ??
                      run.scheduledAt ??
                      '-',
                  style: const TextStyle(
                      fontSize: 9.5, color: AppTheme.textMuted),
                ),
                if (run.errorMessage != null && run.errorMessage!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      run.errorMessage!,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.error),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_label(run.status),
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: _color)),
          ),
        ],
      ),
    );
  }

  String _label(String s) {
    switch (s) {
      case 'completed':
        return 'TAMAM';
      case 'processing':
        return 'İŞLENİYOR';
      case 'failed':
        return 'HATA';
      case 'skipped':
        return 'ATLANDI';
      case 'pending':
        return 'BEKLİYOR';
      default:
        return s.toUpperCase();
    }
  }
}
