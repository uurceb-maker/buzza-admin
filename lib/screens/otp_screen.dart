import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_box.dart';
import 'admin_shell.dart';

/// OTP doğrulama ekranı — Telegram 2FA
class OtpScreen extends StatefulWidget {
  final String otpRedirectUrl;
  final String sessionToken;
  final String siteUrl;

  const OtpScreen({
    super.key,
    required this.otpRedirectUrl,
    required this.sessionToken,
    required this.siteUrl,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;
  static const int _expirySeconds = 180; // 3 dakika

  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  bool _isVerifying = false;
  bool _isResending = false;
  String? _error;
  String? _success;

  int _remainingSeconds = _expirySeconds;
  int _resendCooldown = 0;
  Timer? _timer;
  Timer? _resendTimer;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < _otpLength; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();

    _startExpiryTimer();
  }

  void _startExpiryTimer() {
    _timer?.cancel();
    _remainingSeconds = _expirySeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        t.cancel();
      }
    });
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _resendCooldown = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resendTimer?.cancel();
    _animCtrl.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  String get _timerText {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _siteRoot(String url) {
    final lower = url.toLowerCase();
    final idx = lower.indexOf('/wp-json/');
    if (idx >= 0) return url.substring(0, idx).replaceAll(RegExp(r'/+$'), '');
    return url.replaceAll(RegExp(r'/+$'), '');
  }

  Map<String, String> _ajaxHeaders(String siteRoot) {
    final uri = Uri.parse(siteRoot);
    final origin = '${uri.scheme}://${uri.authority}';
    return {
      'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
      'Accept': 'application/json, text/plain, */*',
      'X-Requested-With': 'XMLHttpRequest',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
      'Origin': origin,
      'Referer': '$origin/',
    };
  }

  Future<void> _verify() async {
    final code = _code;
    if (code.length < _otpLength) {
      setState(() => _error = 'Lütfen $_otpLength haneli kodu girin.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
      _success = null;
    });

    try {
      final siteRoot = _siteRoot(widget.siteUrl);
      final ajaxUrl = '$siteRoot/wp-admin/admin-ajax.php';

      // OTP sayfasından nonce almak gerekli — URL'den parse et
      // AJAX doğrulama için wp_ajax_nopriv_bto_verify_otp kullanıyoruz
      final response = await http.post(
        Uri.parse(ajaxUrl),
        headers: _ajaxHeaders(siteRoot),
        body: {
          'action': 'bto_verify_otp',
          'session_token': widget.sessionToken,
          'code': code,
        },
      ).timeout(const Duration(seconds: 30));

      final respBody = utf8.decode(response.bodyBytes);
      debugPrint('📡 OTP VERIFY STATUS: ${response.statusCode}');
      debugPrint('📡 OTP VERIFY CONTENT-TYPE: ${response.headers['content-type']}');
      debugPrint('📡 OTP VERIFY BODY (first 500): ${respBody.substring(0, respBody.length > 500 ? 500 : respBody.length)}');
      
      if (respBody.trimLeft().startsWith('<')) {
        // HTML yanıtından hata mesajını çıkarmaya çalış
        final titleMatch = RegExp(r'<title>([^<]+)</title>', caseSensitive: false).firstMatch(respBody);
        final errorDetail = titleMatch?.group(1) ?? 'Bilinmeyen hata';
        setState(() => _error = 'Sunucu hatası (HTTP ${response.statusCode}): $errorDetail');
        return;
      }
      final data = json.decode(respBody);

      if (data['success'] == true) {
        final respData = data['data'] ?? {};
        final token = respData['token'] ?? '';
        debugPrint('🔑 OTP VERIFY RESPONSE: $respData');
        debugPrint('🔑 TOKEN: ${token.isEmpty ? "EMPTY" : "${token.substring(0, 20)}..."}');
        debugPrint('🔑 USER: ${respData['user']}');
        
        if (token.isEmpty) {
          setState(() => _error = 'Doğrulama başarılı ama API token alınamadı.');
          return;
        }

        setState(() => _success = 'Doğrulama başarılı! Yönlendiriliyorsunuz...');

        // Token ve kullanıcı verilerini AuthProvider'a kaydet
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.completeOtpLogin(
          token: token,
          siteUrl: widget.siteUrl,
          expiresAt: respData['expires_at']?.toString(),
          userData: respData['user'] is Map ? Map<String, dynamic>.from(respData['user']) : null,
        );

        // Kısa bekle ve AdminShell'e geç
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AdminShell(),
            transitionDuration: const Duration(milliseconds: 350),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      } else {
        final msg = data['data']?['message'] ?? 'Doğrulama başarısız.';
        setState(() => _error = msg);
        // Kodları temizle
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } on TimeoutException {
      setState(
          () => _error = 'Sunucu yanıt vermiyor. Lütfen tekrar deneyin.');
    } catch (e) {
      setState(() => _error = 'Bağlantı hatası: $e');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _error = null;
      _success = null;
    });

    try {
      final siteRoot = _siteRoot(widget.siteUrl);
      final ajaxUrl = '$siteRoot/wp-admin/admin-ajax.php';

      final response = await http.post(
        Uri.parse(ajaxUrl),
        headers: _ajaxHeaders(siteRoot),
        body: {
          'action': 'bto_resend_otp',
          'session_token': widget.sessionToken,
        },
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(utf8.decode(response.bodyBytes));

      if (data['success'] == true) {
        setState(
            () => _success = 'Yeni doğrulama kodu gönderildi.');
        _startExpiryTimer();
        _startResendCooldown();
      } else {
        final msg =
            data['data']?['message'] ?? 'Kod gönderilemedi.';
        setState(() => _error = msg);
      }
    } catch (e) {
      setState(() => _error = 'Bağlantı hatası.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    // Otomatik doğrulama — tüm haneler dolduğunda
    if (_code.length == _otpLength) {
      _verify();
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  // Paste yapıştırma desteği
  void _handlePaste(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    for (int i = 0; i < _otpLength && i < digits.length; i++) {
      _controllers[i].text = digits[i];
    }
    if (digits.length >= _otpLength) {
      _focusNodes[_otpLength - 1].requestFocus();
      _verify();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
                decoration: AppTheme.appBackgroundDecoration()),
          ),
          const Positioned(
            top: -140,
            left: -90,
            child: _OtpOrb(size: 280, color: AppTheme.accentPink),
          ),
          const Positioned(
            bottom: -160,
            right: -100,
            child: _OtpOrb(size: 320, color: AppTheme.primary),
          ),
          FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: GlassBox(
                    borderRadius: 24,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      children: [
                        _buildShieldIcon(),
                        const SizedBox(height: 16),
                        const Text(
                          'İki Faktörlü Doğrulama',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Telegram hesabınıza gönderilen $_otpLength haneli kodu girin.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // OTP Inputs
                        _buildOtpInputs(),
                        const SizedBox(height: 16),

                        // Timer
                        _buildTimer(),
                        const SizedBox(height: 8),

                        // Error / Success
                        if (_error != null) _buildAlert(_error!, isError: true),
                        if (_success != null)
                          _buildAlert(_success!, isError: false),

                        const SizedBox(height: 18),

                        // Verify button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isVerifying ? null : _verify,
                            child: _isVerifying
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Doğrula'),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Resend
                        _buildResendButton(),

                        const SizedBox(height: 14),

                        // Back
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Giriş ekranına dön'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShieldIcon() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentPink.withValues(alpha: 0.3),
            AppTheme.primary.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentPink.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.shield_rounded, size: 34, color: Colors.white),
    );
  }

  Widget _buildOtpInputs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_otpLength, (i) {
        return Container(
          width: 48,
          height: 56,
          margin: EdgeInsets.only(
            left: i == 0 ? 0 : 6,
            right: i == _otpLength - 1 ? 0 : 6,
          ),
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (e) => _onKeyEvent(i, e),
            child: TextField(
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              textAlign: TextAlign.center,
              maxLength: 1,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                filled: true,
                fillColor: AppTheme.bgDark.withValues(alpha: 0.7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppTheme.accentPink,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (v) {
                if (v.length > 1) {
                  // Paste edilmiş olabilir
                  _handlePaste(v);
                  return;
                }
                _onDigitChanged(i, v);
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTimer() {
    final isExpired = _remainingSeconds <= 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.timer_outlined,
          size: 16,
          color: isExpired ? AppTheme.error : AppTheme.textMuted,
        ),
        const SizedBox(width: 6),
        Text(
          isExpired ? 'Kodun süresi doldu' : _timerText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isExpired ? AppTheme.error : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildAlert(String msg, {required bool isError}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isError ? AppTheme.error : AppTheme.success)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isError ? AppTheme.error : AppTheme.success)
              .withValues(alpha: 0.36),
        ),
      ),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isError ? AppTheme.error : AppTheme.success,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildResendButton() {
    if (_resendCooldown > 0) {
      return Text(
        'Yeni kod için ${_resendCooldown}s bekleyin',
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 12,
        ),
      );
    }

    return TextButton(
      onPressed: _isResending ? null : _resend,
      child: _isResending
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text(
              'Kod almadınız mı? Yeniden Gönder',
              style: TextStyle(fontSize: 13),
            ),
    );
  }
}

class _OtpOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _OtpOrb({required this.size, required this.color});

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
              color: color.withValues(alpha: 0.12),
              blurRadius: 80,
              spreadRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}
