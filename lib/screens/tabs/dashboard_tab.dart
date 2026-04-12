import 'dart:math' as math;
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/admin_api.dart';
import '../../widgets/status_badge.dart';

const Color _premiumCyan = Color(0xFF00F0FF);
const Color _premiumViolet = Color(0xFF8A5CFF);
const Color _premiumMint = Color(0xFF2EE6A6);

TextStyle _jakarta({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = Colors.white,
  double height = 1.2,
  double letterSpacing = 0,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  final NumberFormat _currencyFmt = NumberFormat('#,##0.00', 'tr_TR');
  final NumberFormat _intFmt = NumberFormat('#,##0', 'tr_TR');
  late final AnimationController _entryCtrl;
  late final AnimationController _ambientCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _ambientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _ambientCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await AdminApi().getDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      _entryCtrl.forward(from: 0);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
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
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
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

  String _asText(dynamic value, {String fallback = '-'}) {
    final String text = '${value ?? ''}'.trim();
    return text.isEmpty ? fallback : text;
  }

  String _formatCurrency(double value) => '${_currencyFmt.format(value)} TL';

  String _formatDayLabel(dynamic raw, int index) {
    final String label = _asText(raw, fallback: '');
    if (label.isEmpty) return 'G${index + 1}';

    final DateTime? parsed = DateTime.tryParse(label);
    if (parsed != null) {
      return DateFormat('d MMM', 'tr_TR').format(parsed);
    }

    if (label.length > 8) {
      return label.substring(0, 8);
    }
    return label;
  }

  String _timeAgo(DateTime value) {
    final Duration diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'Şimdi';
    if (diff.inHours < 1) return '${diff.inMinutes} dk';
    if (diff.inDays < 1) return '${diff.inHours} sa';
    if (diff.inDays < 30) return '${diff.inDays} gün';
    return DateFormat('d MMM', 'tr_TR').format(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildScene(
        child: Center(
          child: _GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            borderRadius: 28,
            borderColor: _premiumCyan.withValues(alpha: 0.18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: _premiumCyan,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Premium dashboard hazırlanıyor',
                  style: _jakarta(size: 14, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return _buildScene(child: _buildErrorState());
    }

    final Map<String, dynamic> root = _asMap(_data);
    final Map<String, dynamic> payload = _asMap(root['data']);
    var stats = _asMap(root['stats']);
    if (stats.isEmpty) stats = _asMap(payload['stats']);
    if (stats.isEmpty) stats = _asMap(payload['summary']);
    if (stats.isEmpty) stats = payload;

    var recentOrders = _asListMap(root['recent_orders']);
    if (recentOrders.isEmpty) recentOrders = _asListMap(root['orders']);
    if (recentOrders.isEmpty) {
      recentOrders = _asListMap(payload['recent_orders']);
    }
    if (recentOrders.isEmpty) recentOrders = _asListMap(payload['orders']);

    var revenue = _asListMap(root['revenue_7d']);
    if (revenue.isEmpty) revenue = _asListMap(payload['revenue_7d']);
    if (revenue.isEmpty) revenue = _asListMap(payload['revenue']);

    return _buildScene(
      child: RefreshIndicator(
        onRefresh: _load,
        color: _premiumCyan,
        backgroundColor: AppTheme.bgSurface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 118),
          children: [
            _buildStaggered(index: 0, child: _buildHeroPanel(stats)),
            const SizedBox(height: 16),
            _buildStaggered(index: 1, child: _buildOverviewGrid(stats)),
            const SizedBox(height: 16),
            _buildStaggered(index: 2, child: _buildSignalBoard(stats)),
            if (revenue.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildStaggered(index: 3, child: _buildRevenuePanel(revenue)),
            ],
            const SizedBox(height: 16),
            _buildStaggered(
              index: 4,
              child: _buildRecentOrdersPanel(recentOrders),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScene({required Widget child}) {
    return Stack(
      children: [
        Positioned.fill(
          child: _DashboardAmbientBackground(animation: _ambientCtrl),
        ),
        const Positioned.fill(
          child: IgnorePointer(child: _DashboardNoiseOverlay()),
        ),
        child,
      ],
    );
  }

  Widget _buildStaggered({required int index, required Widget child}) {
    final double start = (index * 0.11).clamp(0.0, 0.7);
    final double end = (start + 0.32).clamp(start + 0.01, 1.0);
    final Animation<double> animation = CurvedAnimation(
      parent: _entryCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final double value = animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 28 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildHeroPanel(Map<String, dynamic> stats) {
    final int totalOrders = _asInt(stats['total_orders']);
    final int totalServices = _asInt(stats['total_services']);
    final int totalCategories = _asInt(stats['total_categories']);
    final int pendingOrders = _asInt(stats['pending_orders']);
    final int pendingPayments = _asInt(stats['pending_payments']);
    final double monthRevenue = _asDouble(stats['month_revenue']);
    final double todayRevenue = _asDouble(stats['today_revenue']);
    final int liveSignals = math.max(1, pendingOrders + pendingPayments);
    final int healthScore =
        (100 - math.min(58, pendingOrders * 5 + pendingPayments * 7))
            .clamp(42, 98)
            .round();
    final String dateLabel =
        DateFormat('d MMMM y', 'tr_TR').format(DateTime.now());
    final List<Widget> metricCards = [
      _HeroMetricCapsule(
        title: 'Aylık gelir',
        value: _formatCurrency(monthRevenue),
        suffix: 'Pulse',
        color: _premiumMint,
      ),
      _HeroMetricCapsule(
        title: 'Bugün',
        value: _formatCurrency(todayRevenue),
        suffix: 'Anlık',
        color: _premiumCyan,
      ),
      _HeroMetricCapsule(
        title: 'Katalog',
        value: '$totalCategories kategori',
        suffix: '$totalServices servis',
        color: _premiumViolet,
      ),
      _HeroMetricCapsule(
        title: 'Sipariş',
        value: _intFmt.format(totalOrders),
        suffix: '$pendingOrders beklemede',
        color: AppTheme.warning,
      ),
    ];
    final List<_HeroInsightSpec> heroInsights = [
      _HeroInsightSpec(
        icon: Icons.schedule_send_rounded,
        title: 'Bekleyen sipariş',
        value: '$pendingOrders adet',
        color: AppTheme.warning,
      ),
      _HeroInsightSpec(
        icon: Icons.verified_rounded,
        title: 'Ödeme onayı',
        value: '$pendingPayments talep',
        color: _premiumMint,
      ),
      _HeroInsightSpec(
        icon: Icons.grid_view_rounded,
        title: 'Katalog pulse',
        value: '$totalCategories kategori / $totalServices servis',
        color: _premiumViolet,
      ),
    ];

    return _GlassPanel(
      borderRadius: 30,
      borderColor: Colors.white.withValues(alpha: 0.09),
      gradient: LinearGradient(
        colors: [
          const Color(0xFF0F1730).withValues(alpha: 0.88),
          const Color(0xFF0A1223).withValues(alpha: 0.76),
          _premiumViolet.withValues(alpha: 0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 560;
          final bool narrow = constraints.maxWidth < 390;
          final double gaugeSize = compact ? (narrow ? 142 : 154) : 170;

          final Widget metricsGrid = LayoutBuilder(
            builder: (context, innerConstraints) {
              final double cardWidth = compact
                  ? math.max(128, (innerConstraints.maxWidth - 12) / 2)
                  : 156;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: metricCards
                    .map(
                      (card) => SizedBox(
                        width: cardWidth,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            },
          );

          final Widget heroAside = Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.035),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < heroInsights.length; i++) ...[
                  _HeroInsightTile(item: heroInsights[i]),
                  if (i != heroInsights.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          );

          final Widget left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  const _InfoPill(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Premium Vision',
                    color: _premiumViolet,
                  ),
                  _InfoPill(
                    icon: Icons.bolt_rounded,
                    label: '$liveSignals aktif sinyal',
                    color: _premiumCyan,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Buzza Control Nexus',
                style: _jakarta(
                  size: compact ? 28 : 32,
                  weight: FontWeight.w800,
                  height: 1.02,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sipariş, gelir ve katalog akışlarını tek yüzeyde izleyen premium operasyon paneli.',
                style: _jakarta(
                  size: 14,
                  weight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.58),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateLabel,
                    style: _jakarta(
                      size: 12,
                      weight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              metricsGrid,
            ],
          );

          final Widget gauge = _HeroGauge(
            score: healthScore,
            caption: 'Operasyon skoru',
            helper: '$pendingPayments ödeme onayı bekliyor',
            size: gaugeSize,
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(height: 18),
                if (narrow)
                  Column(
                    children: [
                      Align(alignment: Alignment.center, child: gauge),
                      const SizedBox(height: 14),
                      heroAside,
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: gauge,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(flex: 5, child: heroAside),
                    ],
                  ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: left),
              const SizedBox(width: 18),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(child: gauge),
                    const SizedBox(height: 16),
                    heroAside,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewGrid(Map<String, dynamic> stats) {
    final List<_MetricCardSpec> items = [
      _MetricCardSpec(
        icon: Icons.receipt_long_rounded,
        title: 'Toplam sipariş',
        subtitle: 'Tüm zamanlar katalog hareketi',
        value: _asDouble(stats['total_orders']),
        color: _premiumCyan,
      ),
      _MetricCardSpec(
        icon: Icons.wallet_rounded,
        title: 'Aylık gelir',
        subtitle: 'Bu ay tahmini ciro',
        value: _asDouble(stats['month_revenue']),
        color: _premiumMint,
        currency: true,
      ),
      _MetricCardSpec(
        icon: Icons.grid_view_rounded,
        title: 'Servis havuzu',
        subtitle: 'Yayında olan servis adedi',
        value: _asDouble(stats['total_services']),
        color: _premiumViolet,
      ),
      _MetricCardSpec(
        icon: Icons.group_rounded,
        title: 'Toplam üyeler',
        subtitle: 'Panelde aktif hesap tabanı',
        value: _asDouble(stats['total_users']),
        color: AppTheme.primaryLight,
      ),
    ];

    return _GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(18),
      borderColor: Colors.white.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            eyebrow: 'Realtime Snapshot',
            title: 'Canlı iş akışı görünümü',
            subtitle:
                'Temel KPI kutuları premium cam katmanı üzerinde sunuluyor.',
            accentColor: _premiumCyan,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool singleColumn = constraints.maxWidth < 560;
              if (singleColumn) {
                return Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      _buildMetricCard(items[i]),
                      if (i != items.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items
                    .map(
                      (item) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: _buildMetricCard(item),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(_MetricCardSpec item) {
    return _GlassPanel(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      borderColor: item.color.withValues(alpha: 0.18),
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.05),
          item.color.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      item.color.withValues(alpha: 0.30),
                      item.color.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: item.color.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const Spacer(),
              _InfoPill(
                icon: Icons.trending_up_rounded,
                label: 'Live',
                color: item.color,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _AnimatedMetricValue(
            value: item.value,
            currency: item.currency,
            formatter: item.currency ? _currencyFmt : _intFmt,
            style: _jakarta(
              size: item.currency ? 24 : 28,
              weight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: _jakarta(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: _jakarta(
              size: 12.5,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.62),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBoard(Map<String, dynamic> stats) {
    final int pendingOrders = _asInt(stats['pending_orders']);
    final int pendingPayments = _asInt(stats['pending_payments']);
    final int totalCategories = _asInt(stats['total_categories']);
    final int totalServices = _asInt(stats['total_services']);

    final List<_SignalCardSpec> items = [
      _SignalCardSpec(
        title: 'Sipariş kuyruğu',
        subtitle: 'Bekleyen ve işlemde olan siparişleri anlık takip et.',
        value: _intFmt.format(pendingOrders),
        helper: 'Order pulse',
        color: AppTheme.warning,
        icon: Icons.schedule_send_rounded,
        progress: (pendingOrders / 20).clamp(0.12, 1.0),
      ),
      _SignalCardSpec(
        title: 'Ödeme doğrulama',
        subtitle: 'Yönetici onayı isteyen taleplerin yoğunluğunu izle.',
        value: _intFmt.format(pendingPayments),
        helper: 'Approval queue',
        color: _premiumMint,
        icon: Icons.verified_user_rounded,
        progress: (pendingPayments / 12).clamp(0.10, 1.0),
      ),
      _SignalCardSpec(
        title: 'Katalog pulse',
        subtitle: 'Kategori ve servis havuzunun yayındaki dengesini gösterir.',
        value: '$totalCategories / $totalServices',
        helper: 'Catalog map',
        color: _premiumViolet,
        icon: Icons.auto_graph_rounded,
        progress: totalServices <= 0
            ? 0.10
            : (totalCategories / totalServices).clamp(0.10, 1.0),
      ),
    ];

    return _GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(18),
      borderColor: Colors.white.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            eyebrow: 'Signal Board',
            title: 'Öncelikli operasyon sinyalleri',
            subtitle:
                'Panelin dikkat etmesi gereken alanları tek blokta toplar.',
            accentColor: _premiumViolet,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool singleColumn = constraints.maxWidth < 720;
              if (singleColumn) {
                return Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      _buildSignalCard(items[i]),
                      if (i != items.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    Expanded(child: _buildSignalCard(items[i])),
                    if (i != items.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSignalCard(_SignalCardSpec item) {
    return _GlassPanel(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      borderColor: item.color.withValues(alpha: 0.18),
      gradient: LinearGradient(
        colors: [
          item.color.withValues(alpha: 0.11),
          Colors.white.withValues(alpha: 0.03),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: item.color.withValues(alpha: 0.12),
              border: Border.all(color: item.color.withValues(alpha: 0.20)),
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: _jakarta(size: 15, weight: FontWeight.w700),
                      ),
                    ),
                    _InfoPill(
                      icon: Icons.blur_on_rounded,
                      label: item.helper,
                      color: item.color,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtitle,
                  style: _jakarta(
                    size: 12.5,
                    weight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.64),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: item.progress,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(item.color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.value,
                style: _jakarta(
                  size: 18,
                  weight: FontWeight.w800,
                  color: item.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'İzleniyor',
                style: _jakarta(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenuePanel(List<Map<String, dynamic>> revenue) {
    final List<FlSpot> spots = [];
    final List<String> labels = [];

    for (int i = 0; i < revenue.length; i++) {
      final Map<String, dynamic> item = revenue[i];
      final double amount = _asDouble(
        item['amount'] ?? item['revenue'] ?? item['total'] ?? item['value'],
      );
      spots.add(FlSpot(i.toDouble(), amount));
      labels.add(
        _formatDayLabel(
          item['label'] ?? item['day'] ?? item['date'] ?? item['name'],
          i,
        ),
      );
    }

    final double maxValue =
        spots.isEmpty ? 0 : spots.map((spot) => spot.y).reduce(math.max);
    final double totalRevenue =
        spots.fold<double>(0, (sum, spot) => sum + spot.y);
    final double averageRevenue =
        spots.isEmpty ? 0 : totalRevenue / spots.length;
    final double chartMaxY = maxValue <= 0 ? 10 : maxValue * 1.28;

    return _GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(18),
      borderColor: _premiumMint.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: _SectionHeading(
                  eyebrow: 'Revenue Pulse',
                  title: 'Gelir akış panoraması',
                  subtitle:
                      'Son günlerdeki finansal ritmi daha rafine bir çizgide sunar.',
                  accentColor: _premiumMint,
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              _InfoPill(
                icon: Icons.show_chart_rounded,
                label: _formatCurrency(totalRevenue),
                color: _premiumMint,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final bool compact = constraints.maxWidth < 520;
              final Widget stats = compact
                  ? Column(
                      children: [
                        _MiniStatBlock(
                          title: 'Günlük ortalama',
                          value: _formatCurrency(averageRevenue),
                          color: _premiumCyan,
                        ),
                        const SizedBox(height: 10),
                        _MiniStatBlock(
                          title: 'Tepe nokta',
                          value: _formatCurrency(maxValue),
                          color: _premiumMint,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _MiniStatBlock(
                            title: 'Günlük ortalama',
                            value: _formatCurrency(averageRevenue),
                            color: _premiumCyan,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniStatBlock(
                            title: 'Tepe nokta',
                            value: _formatCurrency(maxValue),
                            color: _premiumMint,
                          ),
                        ),
                      ],
                    );
              return stats;
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 248,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: math.max(0, spots.length - 1).toDouble(),
                minY: 0,
                maxY: chartMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: chartMaxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: chartMaxY / 4,
                      getTitlesWidget: (value, meta) => Text(
                        value <= 0
                            ? '0'
                            : '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k',
                        style: _jakarta(
                          size: 10.5,
                          weight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.44),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final int index = value.round();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[index],
                            style: _jakarta(
                              size: 10.5,
                              weight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.46),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipRoundedRadius: 16,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    getTooltipColor: (_) => const Color(0xFF09101D),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final int index = spot.x.round();
                        final String label = index >= 0 && index < labels.length
                            ? labels[index]
                            : 'Gün';
                        return LineTooltipItem(
                          '$label\n${_formatCurrency(spot.y)}',
                          _jakarta(
                            size: 12,
                            weight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.45,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    spots: spots,
                    barWidth: 3.6,
                    color: _premiumCyan,
                    gradient: const LinearGradient(
                      colors: [_premiumCyan, _premiumViolet, _premiumMint],
                    ),
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: _premiumCyan,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF07111F),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          _premiumCyan.withValues(alpha: 0.20),
                          _premiumViolet.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersPanel(List<Map<String, dynamic>> orders) {
    return _GlassPanel(
      borderRadius: 28,
      padding: const EdgeInsets.all(18),
      borderColor: _premiumCyan.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: _SectionHeading(
                  eyebrow: 'Command Feed',
                  title: 'Son sipariş akışı',
                  subtitle:
                      'Yeni siparişler modern feed düzeniyle daha hızlı taranır.',
                  accentColor: _premiumCyan,
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              _InfoPill(
                icon: Icons.receipt_long_rounded,
                label: '${orders.length} kayıt',
                color: _premiumCyan,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 28,
                    color: Colors.white.withValues(alpha: 0.40),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Gösterilecek sipariş bulunmuyor',
                    style: _jakarta(size: 14, weight: FontWeight.w700),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < orders.length && i < 10; i++) ...[
                  _buildOrderTile(orders[i]),
                  if (i != math.min(orders.length, 10) - 1)
                    const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOrderTile(Map<String, dynamic> order) {
    final String orderId = _asText(order['id'] ?? order['order_id']);
    final String status = _asText(order['status'], fallback: 'pending');
    final String customer = _asText(
      order['customer_name'] ??
          order['user_name'] ??
          order['username'] ??
          order['user'],
      fallback: 'Müşteri',
    );
    final String service = _asText(
      order['service_name'] ?? order['service'] ?? order['title'],
      fallback: 'Servis',
    );
    final double amount = _asDouble(
      order['charge'] ?? order['amount'] ?? order['price'] ?? order['total'],
    );
    final String createdRaw = _asText(
      order['created_at'] ??
          order['date'] ??
          order['createdAt'] ??
          order['created'],
      fallback: '',
    );
    final DateTime? createdAt = DateTime.tryParse(createdRaw);
    final Color statusColor = AppTheme.statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  statusColor.withValues(alpha: 0.28),
                  statusColor.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: statusColor.withValues(alpha: 0.22)),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$orderId',
              textAlign: TextAlign.center,
              style: _jakarta(
                size: 11,
                weight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _jakarta(size: 14, weight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    StatusBadge(status: status, fontSize: 9),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  service,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _jakarta(
                    size: 12.5,
                    weight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.64),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrency(amount),
                style: _jakarta(size: 13, weight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                createdAt != null ? _timeAgo(createdAt) : '-',
                style: _jakarta(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _GlassPanel(
          borderRadius: 28,
          padding: const EdgeInsets.all(24),
          borderColor: AppTheme.error.withValues(alpha: 0.20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.error.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.20),
                    ),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.error,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Dashboard yüklenemedi',
                  style: _jakarta(size: 18, weight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  _error ?? 'Bilinmeyen bir hata oluştu.',
                  textAlign: TextAlign.center,
                  style: _jakarta(
                    size: 13.5,
                    weight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.66),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _load,
                  style: FilledButton.styleFrom(
                    backgroundColor: _premiumCyan,
                    foregroundColor: const Color(0xFF051018),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    'Tekrar dene',
                    style: _jakarta(
                      size: 13,
                      weight: FontWeight.w800,
                      color: const Color(0xFF051018),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCardSpec {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final Color color;
  final bool currency;

  const _MetricCardSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    this.currency = false,
  });
}

class _SignalCardSpec {
  final String title;
  final String subtitle;
  final String value;
  final String helper;
  final Color color;
  final IconData icon;
  final double progress;

  const _SignalCardSpec({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.helper,
    required this.color,
    required this.icon,
    required this.progress,
  });
}

class _HeroInsightSpec {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _HeroInsightSpec({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });
}

class _DashboardAmbientBackground extends StatelessWidget {
  final Animation<double> animation;

  const _DashboardAmbientBackground({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final double t = animation.value;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF03050B),
                Color(0xFF060A14),
                Color(0xFF081224),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.75, -0.9),
                      radius: 1.25,
                      colors: [
                        _premiumCyan.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              _GlowOrb(
                size: 280,
                color: _premiumCyan,
                top: -60 + math.sin(t * math.pi * 2) * 24,
                left: -40 + math.cos(t * math.pi) * 22,
              ),
              _GlowOrb(
                size: 320,
                color: _premiumViolet,
                top: 150 + math.cos(t * math.pi * 2) * 28,
                right: -70 + math.sin(t * math.pi * 2) * 18,
              ),
              _GlowOrb(
                size: 240,
                color: _premiumMint,
                bottom: -30 + math.sin(t * math.pi * 1.3) * 30,
                left: 40 + math.cos(t * math.pi * 1.5) * 18,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  const _GlowOrb({
    required this.size,
    required this.color,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 58, sigmaY: 58),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.24),
                  blurRadius: 140,
                  spreadRadius: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardNoiseOverlay extends StatelessWidget {
  const _DashboardNoiseOverlay();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.28,
      child: CustomPaint(
        painter: _NoisePainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (int y = 0; y < size.height; y += 18) {
      for (int x = 0; x < size.width; x += 18) {
        final double wave = (math.sin(x * 0.18) + math.cos(y * 0.11) + 2) / 4;
        final double alpha = 0.012 + (wave * 0.03);
        paint.color = Colors.white.withValues(alpha: alpha);
        canvas.drawCircle(
          Offset(x.toDouble(), y.toDouble()),
          0.7 + ((x + y) % 3) * 0.18,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Gradient? gradient;
  final Color? borderColor;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 24,
    this.gradient,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradient ??
                LinearGradient(
                  colors: [
                    const Color(0xFF121C2F).withValues(alpha: 0.72),
                    const Color(0xFF0A1120).withValues(alpha: 0.68),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.07),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool compact;

  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: _jakarta(
            size: compact ? 10.5 : 11.5,
            weight: FontWeight.w800,
            color: accentColor,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: _jakarta(
            size: compact ? 20 : 24,
            weight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: _jakarta(
            size: compact ? 12.5 : 13,
            weight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.62),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          SizedBox(width: compact ? 6 : 8),
          Text(
            label,
            style: _jakarta(
              size: compact ? 11 : 12,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetricCapsule extends StatelessWidget {
  final String title;
  final String value;
  final String suffix;
  final Color color;

  const _HeroMetricCapsule({
    required this.title,
    required this.value,
    required this.suffix,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 136),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: _jakarta(
              size: 11.5,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: _jakarta(
              size: 15,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            suffix,
            style: _jakarta(
              size: 11.5,
              weight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.50),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroInsightTile extends StatelessWidget {
  final _HeroInsightSpec item;

  const _HeroInsightTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: item.color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: item.color.withValues(alpha: 0.12),
            ),
            child: Icon(item.icon, color: item.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: _jakarta(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _jakarta(size: 12.5, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroGauge extends StatelessWidget {
  final int score;
  final String caption;
  final String helper;
  final double size;

  const _HeroGauge({
    required this.score,
    required this.caption,
    required this.helper,
    this.size = 170,
  });

  @override
  Widget build(BuildContext context) {
    final double ratio = (score / 100).clamp(0.0, 1.0);
    final double ringSize = size * 0.81;
    final double coreSize = size * 0.66;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: size * 0.065,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        _premiumCyan,
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: coreSize,
                height: coreSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF07101E).withValues(alpha: 0.92),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$score',
                      style: _jakarta(
                        size: size * 0.20,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'skor',
                      style: _jakarta(
                        size: size * 0.07,
                        weight: FontWeight.w700,
                        color: _premiumMint,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          caption,
          style: _jakarta(size: 15, weight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: size + 56,
          child: Text(
            helper,
            textAlign: TextAlign.center,
            style: _jakarta(
              size: 12.5,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.58),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStatBlock extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MiniStatBlock({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _jakarta(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.56),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: _jakarta(size: 14, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedMetricValue extends StatelessWidget {
  final double value;
  final bool currency;
  final NumberFormat formatter;
  final TextStyle style;

  const _AnimatedMetricValue({
    required this.value,
    required this.currency,
    required this.formatter,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, current, _) {
        final String text = currency
            ? '${formatter.format(current)} TL'
            : formatter.format(current.round());
        return Text(text, style: style);
      },
    );
  }
}
