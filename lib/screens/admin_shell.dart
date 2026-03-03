import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/categories_tab.dart';
import 'tabs/orders_tab.dart';
import 'tabs/users_tab.dart';
import 'tabs/payments_tab.dart';
import 'tabs/support_tab.dart';
import 'tabs/security_tab.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  // Bottom nav ↔ tab index mapping
  // Bottom: 0=Dashboard, 1=Siparişler, 2=Kullanıcılar, 3=Ödemeler, 4=Destek
  // Tabs:   0=Dashboard, 1=BuzzaServis, 2=Kategoriler, 3=Siparişler, 4=Kullanıcılar, 5=Ödemeler, 6=Destek, 7=Güvenlik
  static const _bottomIndexMap = {0: 0, 3: 1, 4: 2, 5: 3, 6: 4}; // tab → bottom
  static const _bottomToTabMap = {0: 0, 1: 3, 2: 4, 3: 5, 4: 6}; // bottom → tab

  static const _tabs = [
    _TabInfo(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _TabInfo(icon: Icons.settings_rounded, label: 'Buzza Servis Ayarları'),
    _TabInfo(icon: Icons.category_rounded, label: 'Kategoriler'),
    _TabInfo(icon: Icons.inventory_2_rounded, label: 'Siparişler'),
    _TabInfo(icon: Icons.people_rounded, label: 'Kullanıcılar'),
    _TabInfo(icon: Icons.payment_rounded, label: 'Ödemeler'),
    _TabInfo(icon: Icons.chat_bubble_rounded, label: 'Destek'),
    _TabInfo(icon: Icons.shield_rounded, label: 'Güvenlik'),
  ];

  final _pages = const [
    DashboardTab(),
    SettingsTab(),
    CategoriesTab(),
    OrdersTab(),
    UsersTab(),
    PaymentsTab(),
    SupportTab(),
    SecurityTab(),
  ];

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context); // Close drawer
  }

  Future<void> _logout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_currentIndex].label),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => setState(() {}), // Triggers rebuild = refresh
          ),
        ],
      ),
      drawer: _buildDrawer(auth),
      body: IndexedStack(index: _currentIndex, children: _pages),
      // Bottom nav for quick tabs (first 5)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          border: Border(top: BorderSide(color: AppTheme.glassBorder)),
        ),
        child: BottomNavigationBar(
          currentIndex: _bottomIndexMap.containsKey(_currentIndex) ? _bottomIndexMap[_currentIndex]! : 0,
          onTap: (i) => setState(() => _currentIndex = _bottomToTabMap[i]!),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Siparişler'),
            BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Kullanıcılar'),
            BottomNavigationBarItem(icon: Icon(Icons.payment_rounded), label: 'Ödemeler'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'Destek'),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(AuthProvider auth) {
    return Drawer(
      backgroundColor: AppTheme.bgCard,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.glassBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accentPink]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.userName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(auth.userEmail, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (var i = 0; i < _tabs.length; i++) ...[
                    if (i == 6) const Divider(color: AppTheme.glassBorder, height: 16, indent: 16, endIndent: 16),
                    _DrawerItem(
                      icon: _tabs[i].icon,
                      label: _tabs[i].label,
                      selected: _currentIndex == i,
                      onTap: () => _switchTab(i),
                    ),
                  ],
                ],
              ),
            ),

            // Logout
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.glassBorder)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Çıkış Yap'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabInfo {
  final IconData icon;
  final String label;
  const _TabInfo({required this.icon, required this.label});
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? AppTheme.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? AppTheme.primaryLight : AppTheme.textMuted),
                const SizedBox(width: 14),
                Text(label, style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppTheme.primaryLight : AppTheme.textSecondary,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
