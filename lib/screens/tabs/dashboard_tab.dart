import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/admin_api.dart';
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
  late final AnimationController _animCtrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AdminApi().getDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asListMap(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null) {
      return _buildError();
    }

    final root = _asMap(_data);
    final payload = _asMap(root['data']);

    var stats = _asMap(root['stats']);
    if (stats.isEmpty) stats = _asMap(payload['stats']);
    if (stats.isEmpty) stats = _asMap(payload['summary']);
    if (stats.isEmpty) stats = payload;

    var recentOrders = _asListMap(root['recent_orders']);
    if (recentOrders.isEmpty) recentOrders = _asListMap(root['orders']);
    if (recentOrders.isEmpty) recentOrders = _asListMap(payload['recent_orders']);
    if (recentOrders.isEmpty) recentOrders = _asListMap(payload['orders']);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
        children: [
          _buildWelcomeHeader(stats),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => Opacity(
              opacity: _anim.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - _anim.value)),
                child: _buildKpiGrid(stats),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildAttentionCards(stats),
          const SizedBox(height: 14),
          _buildRevenueChart(root, payload),
          const SizedBox(height: 14),
          _buildRecentOrdersSection(recentOrders),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(Map<String, dynamic> stats) {
    final pendingOrders = _asInt(stats['pending_orders']);
    final pendingPayments = _asInt(stats['pending_payments']);
    final total = pendingOrders + pendingPayments;
    final totalOrders = _asInt(stats['total_orders']);
    final monthRevenue = _asDouble(stats['month_revenue']);
    final nowText = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(DateTime.now());
    final activity = totalOrders > 0 ? ((pendingOrders / totalOrders) * 100).clamp(0, 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.22),
            AppTheme.accentPink.withValues(alpha: 0.1),
            AppTheme.info.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -28,
            right: -18,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -24,
            left: -24,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentPink.withValues(alpha: 0.12),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Operasyon Merkezi',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nowText,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildInfoChip(
                          icon: Icons.pending_actions_rounded,
                          text: total > 0 ? '$total bekleyen işlem' : 'Bekleyen işlem yok',
                          color: total > 0 ? AppTheme.warning : AppTheme.success,
                        ),
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          icon: Icons.account_balance_wallet_rounded,
                          text: '${_fmt.format(monthRevenue)} ₺',
                          color: AppTheme.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Aktif sipariş yoğunluğu: %$activity',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _AlertGauge(count: total),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(Map<String, dynamic> stats) {
    final items = <_MetricItem>[
      _MetricItem(
        icon: Icons.inventory_2_rounded,
        title: 'Toplam Sipariş',
        value: _animatedInt(stats['total_orders']),
        hint: 'Bugün: ${_asInt(stats['today_orders'])}',
        color: AppTheme.info,
      ),
      _MetricItem(
        icon: Icons.attach_money_rounded,
        title: 'Bu Ay Gelir',
        value: '${_fmt.format(_animatedDouble(stats['month_revenue']))} ₺',
        hint: 'Bugün: ${_fmt.format(_asDouble(stats['today_revenue']))} ₺',
        color: AppTheme.success,
      ),
      _MetricItem(
        icon: Icons.shopping_cart_rounded,
        title: 'Aktif Servis',
        value: _animatedInt(stats['total_services']),
        hint: '${_asInt(stats['total_categories'])} kategori',
        color: AppTheme.primary,
      ),
      _MetricItem(
        icon: Icons.people_alt_rounded,
        title: 'Toplam Kullanıcı',
        value: _animatedInt(stats['total_users']),
        hint: 'Sistemde kayıtlı',
        color: AppTheme.accentPink,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (item) => SizedBox(
                  width: cardWidth,
                  child: _buildMetricCard(item),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildMetricCard(_MetricItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 18, color: item.color),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: item.color.withValues(alpha: 0.9)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            item.title,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            item.hint,
            style: TextStyle(fontSize: 10.5, color: item.color.withValues(alpha: 0.95), fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionCards(Map<String, dynamic> stats) {
    final pendingOrders = _asInt(stats['pending_orders']);
    final pendingPayments = _asInt(stats['pending_payments']);
    final totalOrders = _asInt(stats['total_orders']);
    final totalUsers = _asInt(stats['total_users']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildAttentionCard(
                title: 'Sipariş Kuyruğu',
                icon: Icons.hourglass_bottom_rounded,
                value: '$pendingOrders',
                subtitle: 'Toplamdaki oran: %${totalOrders > 0 ? ((pendingOrders / totalOrders) * 100).round() : 0}',
                progress: totalOrders > 0 ? (pendingOrders / totalOrders).clamp(0, 1).toDouble() : 0,
                color: AppTheme.warning,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildAttentionCard(
                title: 'Ödeme Onayı',
                icon: Icons.credit_score_rounded,
                value: '$pendingPayments',
                subtitle: 'Kullanıcıya oran: %${totalUsers > 0 ? ((pendingPayments / totalUsers) * 100).round() : 0}',
                progress: totalUsers > 0 ? (pendingPayments / totalUsers).clamp(0, 1).toDouble() : 0,
                color: AppTheme.error,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAttentionCard({
    required String title,
    required IconData icon,
    required String value,
    required String subtitle,
    required double progress,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.glassBorder,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _animatedInt(dynamic value) {
    final target = _asInt(value);
    return '${(target * _anim.value).round()}';
  }

  double _animatedDouble(dynamic value) {
    return _asDouble(value) * _anim.value;
  }

  Widget _buildRevenueChart(Map<String, dynamic> root, Map<String, dynamic> payload) {
    var revenue = _asListMap(root['revenue_7d']);
    if (revenue.isEmpty) revenue = _asListMap(payload['revenue_7d']);
    if (revenue.isEmpty) revenue = _asListMap(payload['revenue']);
    if (revenue.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    final labels = <String>[];
    var maxVal = 0.0;

    for (var i = 0; i < revenue.length; i++) {
      final val = _asDouble(revenue[i]['total']);
      final day = '${revenue[i]['day'] ?? revenue[i]['date'] ?? ''}';
      spots.add(FlSpot(i.toDouble(), val));
      labels.add(day.length >= 10 ? day.substring(5) : day);
      if (val > maxVal) maxVal = val;
    }
    final totalRevenue = spots.fold<double>(0, (sum, s) => sum + s.y);
    final avgRevenue = spots.isNotEmpty ? totalRevenue / spots.length : 0;
    final chartMaxY = maxVal > 0 ? maxVal * 1.15 : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 18, color: AppTheme.success),
              const SizedBox(width: 7),
              const Text('Gelir Trendi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              _buildMiniPill('Toplam: ${_fmt.format(totalRevenue)} ₺', AppTheme.success),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Son 7 gün ortalama: ${_fmt.format(avgRevenue)} ₺',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
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
                    barWidth: 3.2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3.5,
                        color: AppTheme.primary,
                        strokeWidth: 1.8,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.2),
                          AppTheme.accentPink.withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.bgDark,
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            '${_fmt.format(s.y)} ₺',
                            const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        )
                        .toList(),
                  ),
                ),
                minY: 0,
                maxY: chartMaxY,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildRecentOrdersSection(List<Map<String, dynamic>> orders) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, size: 17, color: AppTheme.primary),
              const SizedBox(width: 7),
              const Text('Son Siparişler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              _buildMiniPill('${orders.length} kayıt', AppTheme.primary),
            ],
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(
                color: AppTheme.bgDark.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 38, color: AppTheme.textMuted),
                  SizedBox(height: 8),
                  Text('Sipariş kaydı bulunamadı', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            )
          else
            ...orders.take(10).map(_buildOrderRow),
        ],
      ),
    );
  }

  Widget _buildOrderRow(Map<String, dynamic> order) {
    final createdAt = '${order['created_at'] ?? ''}';
    var timeAgo = '';

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

    final status = '${order['status'] ?? 'pending'}';
    final statusColor = AppTheme.statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8.5),
      decoration: BoxDecoration(
        color: AppTheme.bgDark.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 66,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(
                      child: Text(
                        '#${order['id'] ?? '-'}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${order['user_name'] ?? '-'}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            StatusBadge(status: status, fontSize: 9),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${order['service_name'] ?? '-'}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_fmt.format(_asDouble(order['total_price']))} ₺',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      if (timeAgo.isNotEmpty) Text(timeAgo, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
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

class _MetricItem {
  final IconData icon;
  final String title;
  final String value;
  final String hint;
  final Color color;

  const _MetricItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.hint,
    required this.color,
  });
}

class _AlertGauge extends StatelessWidget {
  final int count;

  const _AlertGauge({required this.count});

  @override
  Widget build(BuildContext context) {
    final safe = count.clamp(0, 99);
    final progress = safe > 0 ? (safe / 100).toDouble() : 0.08;
    final gaugeColor = safe > 0 ? AppTheme.warning : AppTheme.success;

    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6.5,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Center(
              child: Text(
                '$count',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: gaugeColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
