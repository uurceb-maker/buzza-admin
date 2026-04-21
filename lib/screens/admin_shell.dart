import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../services/support_notification_service.dart';
import 'katalog_screen.dart';
import 'login_screen.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/notifications_campaign_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/payments_tab.dart';
import 'tabs/security_tab.dart';
import 'tabs/services_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/support_tab.dart';
import 'tabs/users_tab.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<KatalogScreenState> _katalogKey =
      GlobalKey<KatalogScreenState>();

  // Bildirim paneli overlay
  OverlayEntry? _notifOverlay;

  static const _tabs = [
    _TabInfo(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _TabInfo(icon: Icons.design_services_rounded, label: 'Servisler'),
    _TabInfo(icon: Icons.campaign_rounded, label: 'Bildirim ve Kampanyalar'),
    _TabInfo(icon: Icons.settings_rounded, label: 'Ayarlar'),
    _TabInfo(icon: Icons.grid_view_rounded, label: 'Katalog'),
    _TabInfo(icon: Icons.inventory_2_rounded, label: 'Siparişler'),
    _TabInfo(icon: Icons.people_rounded, label: 'Kullanıcılar'),
    _TabInfo(icon: Icons.payment_rounded, label: 'Ödemeler'),
    _TabInfo(icon: Icons.chat_bubble_rounded, label: 'Destek'),
    _TabInfo(icon: Icons.shield_rounded, label: 'Güvenlik'),
  ];

  late final List<Widget> _pages = [
    const DashboardTab(),
    const ServicesTab(),
    const NotificationsCampaignTab(),
    const SettingsTab(),
    KatalogScreen(key: _katalogKey),
    const OrdersTab(),
    const UsersTab(),
    const PaymentsTab(),
    const SupportTab(),
    const SecurityTab(),
  ];

  bool _isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1024;

  List<int> _visibleTabIndexes(AuthProvider auth) {
    final all = List<int>.generate(_tabs.length, (index) => index);
    if (auth.canManageOptions) return all;

    // Editor/operator/accounting gibi sınırlı rollerde kritik sekmeleri gizle.
    return all.where((index) => index != 3 && index != 9).toList();
  }

  List<int> _bottomTabIndexes(List<int> visibleTabIndexes) {
    const preferred = <int>[0, 5, 6, 7, 8];
    final indexes =
        preferred.where((index) => visibleTabIndexes.contains(index)).toList();
    if (indexes.length >= 2) return indexes;
    return visibleTabIndexes.take(2).toList();
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
    // Destek sekmesine geçince okunmamış sayısını sıfırla
    // ve sistem bildirimlerini bastır (tab kendi bildirimini yapıyor)
    final notifService = SupportNotificationService.instance;
    notifService.supportTabActive = index == 8;
    if (index == 8) {
      notifService.unreadCount.value = 0;
    }
    _closeNotifPanel();
    // Sadece mobil drawer aciksa kapat; route stack'te geri gitme.
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _toggleNotifPanel() {
    if (_notifOverlay != null) {
      _closeNotifPanel();
    } else {
      _openNotifPanel();
    }
  }

  void _closeNotifPanel() {
    _notifOverlay?.remove();
    _notifOverlay = null;
  }

  void _openNotifPanel() {
    final overlay = Overlay.of(context);
    final appBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    final panelWidth =
        (MediaQuery.sizeOf(context).width * 0.75).clamp(200.0, 300.0);

    _notifOverlay = OverlayEntry(
      builder: (_) {
        return Stack(
          children: [
            // Barrier — dışa tıklayınca kapan
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeNotifPanel,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Panel
            Positioned(
              top: appBarHeight,
              left: 0,
              width: panelWidth,
              child: Material(
                color: Colors.transparent,
                child: _NotifPanel(
                  onGoSupport: () {
                    _closeNotifPanel();
                    _switchTab(8);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_notifOverlay!);
  }

  Future<void> _logout() async {
    _closeNotifPanel();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDesktop = _isDesktop(context);

    final visibleTabIndexes = _visibleTabIndexes(auth);
    if (visibleTabIndexes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Buzza Admin')),
        body: const Center(
          child: Text('Bu hesap için erişilebilir sekme bulunamadı.'),
        ),
      );
    }

    final activeIndex = visibleTabIndexes.contains(_currentIndex)
        ? _currentIndex
        : visibleTabIndexes.first;

    if (activeIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentIndex = activeIndex);
      });
    }

    final bottomTabIndexes = _bottomTabIndexes(visibleTabIndexes);

    return Scaffold(
      key: _scaffoldKey,
      extendBody: !isDesktop,
      appBar: _buildAppBar(isDesktop, activeIndex),
      drawer:
          isDesktop ? null : _buildDrawer(auth, visibleTabIndexes, activeIndex),
      body: Stack(
        children: [
          Positioned.fill(
              child:
                  DecoratedBox(decoration: AppTheme.appBackgroundDecoration())),
          const Positioned(
              top: -140,
              right: -90,
              child: _BackdropOrb(size: 320, color: AppTheme.primaryLight)),
          const Positioned(
              bottom: -180,
              left: -120,
              child: _BackdropOrb(size: 360, color: AppTheme.accentPink)),
          SafeArea(
            top: false,
            child: isDesktop
                ? Row(
                    children: [
                      const SizedBox(width: 14),
                      _buildDesktopRail(auth, visibleTabIndexes, activeIndex),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildPageSurface(
                          isDesktop: true,
                          currentIndex: activeIndex,
                        ),
                      ),
                    ],
                  )
                : _buildPageSurface(
                    isDesktop: false, currentIndex: activeIndex),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop || bottomTabIndexes.length < 2
          ? null
          : _buildBottomBar(bottomTabIndexes, activeIndex),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDesktop, int currentIndex) {
    final catalogColors = context.catalogColors;
    final isCatalogTab = _tabs[currentIndex].label == 'Katalog';
    final liveColor =
        isCatalogTab ? catalogColors.activeGreen : AppTheme.success;
    final refreshColor = isCatalogTab ? catalogColors.accentBlue : Colors.white;

    return AppBar(
      titleSpacing: isDesktop ? 22 : 6,
      title: Row(
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _tabs[currentIndex].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Buzza Admin Kontrol Merkezi',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // ─── Bildirim çan butonu ───
        ValueListenableBuilder<int>(
          valueListenable:
              SupportNotificationService.instance.unreadCount,
          builder: (context, count, _) {
            return IconButton(
              tooltip: 'Destek Bildirimleri',
              onPressed: _toggleNotifPanel,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_rounded,
                      size: 22, color: Colors.white),
                  if (count > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        height: 16,
                        constraints:
                            const BoxConstraints(minWidth: 16),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: AppTheme.bgDark, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: liveColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: liveColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.circle, color: liveColor, size: 8),
              const SizedBox(width: 6),
              Text('Canlı',
                  style: TextStyle(
                      fontSize: 11,
                      color: liveColor,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Yenile',
          icon: Icon(Icons.refresh_rounded, size: 21, color: refreshColor),
          onPressed: () {
            if (isCatalogTab) {
              _katalogKey.currentState?.refreshMockData();
              return;
            }
            setState(() {});
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildPageSurface(
      {required bool isDesktop, required int currentIndex}) {
    final page = IndexedStack(index: currentIndex, children: _pages);

    if (!isDesktop) {
      return page;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: AppTheme.glassGradientDecoration(radius: 24),
          child: page,
        ),
      ),
    );
  }

  Widget _buildBottomBar(List<int> bottomTabIndexes, int currentIndex) {
    final activeBottomIndex = bottomTabIndexes.indexOf(currentIndex);
    final safeBottomIndex = activeBottomIndex >= 0 ? activeBottomIndex : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: AppTheme.shellChromeDecoration(radius: 20),
          child: BottomNavigationBar(
            currentIndex: safeBottomIndex,
            onTap: (i) => setState(() => _currentIndex = bottomTabIndexes[i]),
            items: [
              for (final tabIndex in bottomTabIndexes)
                BottomNavigationBarItem(
                  icon: Icon(_tabs[tabIndex].icon),
                  label: _tabs[tabIndex].label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopRail(
    AuthProvider auth,
    List<int> visibleTabIndexes,
    int currentIndex,
  ) {
    return Container(
      width: 286,
      margin: const EdgeInsets.fromLTRB(0, 12, 0, 14),
      decoration: AppTheme.glassGradientDecoration(radius: 24),
      child: Column(
        children: [
          _buildUserHeader(auth, compact: false),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              children: [
                for (final i in visibleTabIndexes) ...[
                  if (i == 8)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      child: Text(
                        'Destek ve Güvenlik',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  _NavigationItem(
                    icon: _tabs[i].icon,
                    label: _tabs[i].label,
                    selected: currentIndex == i,
                    onTap: () => _switchTab(i),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Çıkış Yap'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side:
                      BorderSide(color: AppTheme.error.withValues(alpha: 0.38)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(
    AuthProvider auth,
    List<int> visibleTabIndexes,
    int currentIndex,
  ) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: Container(
          decoration: AppTheme.glassGradientDecoration(radius: 0),
          child: SafeArea(
            child: Column(
              children: [
                _buildUserHeader(auth, compact: true),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final i in visibleTabIndexes) ...[
                        if (i == 8)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(18, 10, 18, 8),
                            child:
                                Divider(color: AppTheme.glassBorder, height: 1),
                          ),
                        _NavigationItem(
                          icon: _tabs[i].icon,
                          label: _tabs[i].label,
                          selected: currentIndex == i,
                          onTap: () => _switchTab(i),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Çıkış Yap'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: BorderSide(
                            color: AppTheme.error.withValues(alpha: 0.35)),
                      ),
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

  Widget _buildUserHeader(AuthProvider auth, {required bool compact}) {
    return Container(
      width: double.infinity,
      padding:
          EdgeInsets.fromLTRB(16, compact ? 14 : 18, 16, compact ? 14 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.2),
            AppTheme.accentPink.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: const Border(bottom: BorderSide(color: AppTheme.glassBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 46 : 52,
            height: compact ? 46 : 52,
            decoration: BoxDecoration(
              gradient: AppTheme.headerGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.userName,
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  auth.userEmail,
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabInfo {
  final IconData icon;
  final String label;

  const _TabInfo({required this.icon, required this.label});
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: selected
            ? AppTheme.primary.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color:
                        (selected ? AppTheme.primaryLight : AppTheme.textMuted)
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color:
                        selected ? AppTheme.primaryLight : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppTheme.primaryLight
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryLight,
                      shape: BoxShape.circle,
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

class _BackdropOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BackdropOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.08),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.14),
              blurRadius: 80,
              spreadRadius: 30,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bildirim Paneli (Soldan Kayan Overlay) ──────────────────────────────────
class _NotifPanel extends StatefulWidget {
  final VoidCallback onGoSupport;

  const _NotifPanel({required this.onGoSupport});

  @override
  State<_NotifPanel> createState() => _NotifPanelState();
}

class _NotifPanelState extends State<_NotifPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
    _slide = Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          margin: const EdgeInsets.only(left: 8, right: 8, top: 6),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(4, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.18),
                      AppTheme.accentPink.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_rounded,
                        size: 18, color: AppTheme.primaryLight),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Destek Bildirimleri',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable:
                          SupportNotificationService.instance.unreadCount,
                      builder: (_, count, __) => count > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.error,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                count > 9 ? '9+' : '$count',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              // İçerik
              Padding(
                padding: const EdgeInsets.all(16),
                child: ValueListenableBuilder<int>(
                  valueListenable:
                      SupportNotificationService.instance.unreadCount,
                  builder: (_, count, __) => count > 0
                      ? Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                color: AppTheme.warning,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$count okunmamış mesaj',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Bekleyen destek talepleri var',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: AppTheme.success, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Tüm mesajlar okundu',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              // Buton
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onGoSupport,
                    icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                    label: const Text('Destek Sekmesine Git'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
