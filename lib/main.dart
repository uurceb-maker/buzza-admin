import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/admin_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BuzzaAdminApp());
}

class BuzzaAdminApp extends StatelessWidget {
  const BuzzaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Buzza Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const _SplashScreen(),
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.tryAutoLogin();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => success ? const AdminShell() : const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accentPink]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 24)],
              ),
              child: const Icon(Icons.admin_panel_settings, size: 42, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text('Buzza Admin', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Yönetim Paneli', style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
            const SizedBox(height: 32),
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}
