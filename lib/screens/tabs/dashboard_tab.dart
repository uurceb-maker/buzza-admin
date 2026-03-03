import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../services/admin_api.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> with TickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  final _fmt = NumberFormat('#,##0.00', 'tr_TR');
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await AdminApi().getDashboard();
      setState(() { _data = data; _loading = false; });
      _animCtrl.forward(from: 0);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null) return _buildError();

    final s = _data?['stats'] as Map<String, dynamic>? ?? {};
    final recentOrders = (_data?['recent_orders'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ═══ Welcome Header ═══
          _buildWelcomeHeader(s),
          const SizedBox(height: 20),

          // ═══ KPI Grid ═══
          AnimatedBuilder(
            animation: _anim,
            builder: (ctx, _) => Opacity(
              opacity: _anim.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - _anim.value)),
                child: _buildKpiGrid(s),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ═══ Revenue Chart ═══
          _buildRevenueChart(),
          const SizedBox(height: 20),

          // ═══ Recent Orders ═══
          _buildRecentOrdersSection(recentOrders),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(Map<String, dynamic> s) {
    final pendingOrders = int.tryParse('${s['pending_orders']}') ?? 0;
    final pendingPayments = int.tryParse('${s['pending_payments']}') ?? 0;
    final total = pendingOrders + pendingPayments;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.15), AppTheme.accentPink.withValues(alpha: 0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hoş Geldiniz 👋', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  total > 0
                      ? '$total bekleyen işlem var'
                      : 'Her şey yolunda, bekleyen işlem yok',
                  style: TextStyle(
                    fontSize: 13,
                    color: total > 0 ? AppTheme.warning : AppTheme.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (total > 0)
            _PulsingBadge(count: total),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(Map<String, dynamic> s) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        StatCard(
          icon: Icons.inventory_2_rounded,
          label: 'Toplam Sipariş',
          value: _animatedValue(s, 'total_orders'),
          subtitle: 'Bugün: ${s['today_orders'] ?? 0}',
          iconColor: AppTheme.info,
        ),
        StatCard(
          icon: Icons.attach_money_rounded,
          label: 'Bu Ay Gelir',
          value: '${_fmt.format(_animatedDouble(s, 'month_revenue'))} ₺',
          subtitle: 'Bugün: ${_fmt.format(double.tryParse('${s['today_revenue']}') ?? 0)} ₺',
          iconColor: AppTheme.success,
        ),
        StatCard(
          icon: Icons.shopping_cart_rounded,
          label: 'Aktif Servis',
          value: _animatedValue(s, 'total_services'),
          subtitle: '${s['total_categories'] ?? 0} Kategori',
          iconColor: AppTheme.primary,
        ),
        StatCard(
          icon: Icons.people_rounded,
          label: 'Kullanıcı',
          value: _animatedValue(s, 'total_users'),
          iconColor: AppTheme.accentPink,
        ),
        StatCard(
          icon: Icons.hourglass_bottom_rounded,
          label: 'Bekleyen Sipariş',
          value: _animatedValue(s, 'pending_orders'),
          iconColor: AppTheme.warning,
        ),
        StatCard(
          icon: Icons.payment_rounded,
          label: 'Bekleyen Ödeme',
          value: _animatedValue(s, 'pending_payments'),
          iconColor: AppTheme.error,
        ),
      ],
    );
  }

  String _animatedValue(Map<String, dynamic> s, String key) {
    final target = int.tryParse('${s[key]}') ?? 0;
    return '${(target * _anim.value).round()}';
  }

  double _animatedDouble(Map<String, dynamic> s, String key) {
    final target = double.tryParse('${s[key]}') ?? 0;
    return target * _anim.value;
  }

  Widget _buildRevenueChart() {
    final revenue = (_data?['revenue_7d'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (revenue.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    final labels = <String>[];
    double maxVal = 0;

    for (var i = 0; i < revenue.length; i++) {
      final val = double.tryParse('${revenue[i]['total']}') ?? 0;
      spots.add(FlSpot(i.toDouble(), val));
      labels.add('${revenue[i]['day']}'.length >= 10 ? '${revenue[i]['day']}'.substring(5) : '${revenue[i]['day']}');
      if (val > maxVal) maxVal = val;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, size: 18, color: AppTheme.success),
              const SizedBox(width: 8),
              const Text('Son 7 Gün Gelir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${_fmt.format(spots.fold<double>(0, (sum, s) => sum + s.y))} ₺',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.success),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.glassBorder, strokeWidth: 0.5),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (v, _) => Text(
                        v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toInt().toString(),
                        style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                        return Text(labels[idx], style: const TextStyle(fontSize: 9, color: AppTheme.textMuted));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accentPink]),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: AppTheme.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [AppTheme.primary.withValues(alpha: 0.2), AppTheme.accentPink.withValues(alpha: 0.02)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.bgCard,
                    getTooltipItems: (spots) => spots.map((s) =>
                      LineTooltipItem(
                        '${_fmt.format(s.y)} ₺',
                        const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ).toList(),
                  ),
                ),
                minY: 0,
                maxY: maxVal * 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersSection(List<Map<String, dynamic>> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Son Siparişler', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${orders.length} adet', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: AppTheme.glassDecoration(radius: 16),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 40, color: AppTheme.textMuted),
                  SizedBox(height: 8),
                  Text('Sipariş yok', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            ),
          )
        else
          ...orders.take(10).map(_buildOrderRow),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOrderRow(Map<String, dynamic> o) {
    final createdAt = '${o['created_at'] ?? ''}';
    String timeAgo = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes} dk önce';
        } else if (diff.inHours < 24) {
          timeAgo = '${diff.inHours} saat önce';
        } else {
          timeAgo = '${diff.inDays} gün önce';
        }
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassDecoration(radius: 14),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.statusColor('${o['status'] ?? 'pending'}').withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('#${o['id']}', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: AppTheme.statusColor('${o['status'] ?? 'pending'}'),
              )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${o['user_name'] ?? '-'}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusBadge(status: '${o['status'] ?? 'pending'}', fontSize: 9),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${o['service_name'] ?? '-'}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_fmt.format(double.tryParse('${o['total_price']}') ?? 0)} ₺',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              if (timeAgo.isNotEmpty)
                Text(timeAgo, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══ Pulsing badge for pending items ═══
class _PulsingBadge extends StatefulWidget {
  final int count;
  const _PulsingBadge({required this.count});
  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.warning.withValues(alpha: 0.15 + _ctrl.value * 0.1),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Text(
            '${widget.count}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.warning),
          ),
        ),
      ),
    );
  }
}
