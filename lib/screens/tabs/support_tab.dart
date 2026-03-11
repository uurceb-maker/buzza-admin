import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/theme.dart';
import '../../services/admin_api.dart';
import '../../widgets/status_badge.dart';

class SupportTab extends StatefulWidget {
  const SupportTab({super.key});

  @override
  State<SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<SupportTab> {
  List<dynamic> _items = [];
  int _page = 1;
  int _pages = 1;
  bool _loading = true;

  int _viewMode = 0; // 0 = ticket list, 1 = FreeScout
  WebViewController? _webCtrl;
  bool _webLoading = true;

  bool get _supportsEmbeddedWebView {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();
    _load();

    if (_supportsEmbeddedWebView) {
      _webCtrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) setState(() => _webLoading = true);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _webLoading = false);
            },
          ),
        )
        ..loadRequest(Uri.parse('https://destek.buzza.com.tr'));
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await AdminApi().getTickets(page: _page);
      if (!mounted) return;
      setState(() {
        _items = d['items'] as List? ?? [];
        _pages = d['pages'] ?? 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showTicketChat(Map<String, dynamic> ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TicketChatScreen(ticket: ticket, onBack: _load),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Ticketlar', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.list_alt_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('FreeScout', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.support_agent_rounded, size: 16),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (v) => setState(() => _viewMode = v.first),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppTheme.primary.withValues(alpha: 0.15);
                      }
                      return Colors.transparent;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) return AppTheme.primary;
                      return AppTheme.textMuted;
                    }),
                    side: WidgetStateProperty.all(const BorderSide(color: AppTheme.glassBorder)),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              if (_viewMode == 1) ...[
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _supportsEmbeddedWebView ? () => _webCtrl?.reload() : null,
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.primary),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(child: _viewMode == 0 ? _buildTicketList() : _buildFreeScoutView()),
      ],
    );
  }

  Widget _buildFreeScoutView() {
    if (!_supportsEmbeddedWebView || _webCtrl == null) {
      return _buildWebUnsupported();
    }

    return Column(
      children: [
        if (_webLoading)
          const LinearProgressIndicator(
            backgroundColor: AppTheme.bgCard,
            color: AppTheme.primary,
            minHeight: 2,
          ),
        Expanded(child: WebViewWidget(controller: _webCtrl!)),
      ],
    );
  }

  Widget _buildWebUnsupported() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.web_asset_off_rounded, size: 46, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text(
              'Bu platformda gömülü FreeScout görünümü desteklenmiyor.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
            SizedBox(height: 6),
            Text(
              'Ticketlar sekmesini kullanarak destek taleplerini yönetebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_items.length} destek talebi', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              Text('Sayfa $_page / $_pages', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primary,
                  child: _items.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.support_agent_rounded, size: 48, color: AppTheme.textMuted),
                              SizedBox(height: 12),
                              Text('Destek talebi yok', style: TextStyle(color: AppTheme.textMuted)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _items.length + 1,
                          itemBuilder: (ctx, i) {
                            if (i == _items.length) return _buildPagination();
                            return _buildTicketCard(_items[i]);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(dynamic ticket) {
    final status = '${ticket['status'] ?? 'open'}';
    final source = '${ticket['source'] ?? ''}';

    return GestureDetector(
      onTap: () => _showTicketChat(Map<String, dynamic>.from(ticket as Map)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassDecoration(radius: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _priorityColor(ticket).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                source == 'app' ? Icons.phone_android_rounded : Icons.language_rounded,
                size: 20,
                color: _priorityColor(ticket),
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
                          '${ticket['subject'] ?? '-'}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StatusBadge(status: status, fontSize: 9),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('${ticket['user_name'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      const SizedBox(width: 8),
                      if (source.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            source == 'app' ? 'Uygulama' : 'Site',
                            style: const TextStyle(fontSize: 9, color: AppTheme.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('#${ticket['id']}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                Text('${ticket['created_at'] ?? '-'}', style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(dynamic ticket) {
    switch ('${ticket['priority'] ?? 'normal'}'.toLowerCase()) {
      case 'high':
      case 'urgent':
        return AppTheme.error;
      case 'low':
        return AppTheme.textMuted;
      default:
        return AppTheme.info;
    }
  }

  Widget _buildPagination() {
    if (_pages <= 1) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page > 1
                ? () {
                    _page--;
                    _load();
                  }
                : null,
          ),
          Text('$_page / $_pages', style: const TextStyle(color: AppTheme.textMuted)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page < _pages
                ? () {
                    _page++;
                    _load();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _TicketChatScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onBack;

  const _TicketChatScreen({required this.ticket, required this.onBack});

  @override
  State<_TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<_TicketChatScreen> {
  final _replyCtrl = TextEditingController();
  bool _sending = false;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _parseMessages();
  }

  void _parseMessages() {
    final replies = (widget.ticket['replies'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    _messages = [
      {
        'from': 'user',
        'message': widget.ticket['message'] ?? widget.ticket['subject'] ?? '-',
        'date': widget.ticket['created_at'] ?? '',
        'name': widget.ticket['user_name'] ?? '-',
      },
      ...replies,
    ];
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await AdminApi().replyTicket(widget.ticket['id'], text);
      if (!mounted) return;
      _replyCtrl.clear();
      setState(() {
        _messages.add({
          'from': 'admin',
          'message': text,
          'date': DateTime.now().toIso8601String(),
          'name': 'Admin',
        });
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.onBack();
            Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.ticket['subject'] ?? '-'}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(
              '${widget.ticket['user_name'] ?? '-'} • #${widget.ticket['id']}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => _buildBubble(_messages[i]),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _templateChip('Siparişiniz işleme alındı'),
                _templateChip('Ödemeniz onaylandı'),
                _templateChip('Bakiyeniz güncellendi'),
                _templateChip('Lütfen detay paylaşın'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: const BoxDecoration(
              color: AppTheme.bgCard,
              border: Border(top: BorderSide(color: AppTheme.glassBorder)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      maxLines: 3,
                      minLines: 1,
                      decoration: AppTheme.inputDecoration(hint: 'Cevabınızı yazın...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accentPink]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _sending ? null : _sendReply,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

  Widget _buildBubble(Map<String, dynamic> msg) {
    final isAdmin = msg['from'] == 'admin';
    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isAdmin ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.glassBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: isAdmin ? const Radius.circular(14) : const Radius.circular(4),
            bottomRight: isAdmin ? const Radius.circular(4) : const Radius.circular(14),
          ),
          border: Border.all(
            color: isAdmin ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.glassBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isAdmin)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${msg['name'] ?? '-'}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isAdmin ? AppTheme.primary : AppTheme.accentPink,
                  ),
                ),
              ),
            Text('${msg['message'] ?? ''}', style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 4),
            Text('${msg['date'] ?? ''}', style: const TextStyle(fontSize: 9, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _templateChip(String text) {
    return GestureDetector(
      onTap: () => _replyCtrl.text = text,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.glassBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ),
    );
  }
}
