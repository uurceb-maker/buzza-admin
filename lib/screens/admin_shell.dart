import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'tabs/categories_tab.dart';
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

  static const _tabs = [
    _TabInfo(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _TabInfo(icon: Icons.design_services_rounded, label: 'Servisler'),
    _TabInfo(icon: Icons.campaign_rounded, label: 'Bildirim ve Kampanyalar'),
    _TabInfo(icon: Icons.settings_rounded, label: 'Ayarlar'),
    _TabInfo(icon: Icons.category_rounded, label: 'Kategoriler'),
    _TabInfo(icon: Icons.inventory_2_rounded, label: 'Siparişler'),
    _TabInfo(icon: Icons.people_rounded, label: 'Kullanıcılar'),
    _TabInfo(icon: Icons.payment_rounded, label: 'Ödemeler'),
    _TabInfo(icon: Icons.chat_bubble_rounded, label: 'Destek'),
    _TabInfo(icon: Icons.shield_rounded, label: 'Güvenlik'),
  ];

  final _pages = const [
    DashboardTab(),
    ServicesTab(),
    NotificationsCampaignTab(),
    SettingsTab(),
    CategoriesTab(),
    OrdersTab(),
    UsersTab(),
    PaymentsTab(),
    SupportTab(),
    SecurityTab(),
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
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
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
        Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.circle, color: AppTheme.success, size: 8),
              SizedBox(width: 6),
              Text('Canlı',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.success,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Yenile',
          icon: const Icon(Icons.refresh_rounded, size: 21),
          onPressed: () => setState(() {}),
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
