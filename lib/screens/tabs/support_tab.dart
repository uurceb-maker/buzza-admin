import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/admin_api.dart';
import '../../widgets/status_badge.dart';

class SupportTab extends StatefulWidget {
  const SupportTab({super.key});

  @override
  State<SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<SupportTab> {
  static const Duration _listPollInterval = Duration(seconds: 8);
  static const Duration _threadPollInterval = Duration(seconds: 3);

  final AdminApi _api = AdminApi();
  AudioPlayer? _audioPlayer;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _replyCtrl = TextEditingController();
  final ScrollController _threadScroll = ScrollController();
  final DateFormat _df = DateFormat('dd.MM.yyyy HH:mm');

  final Map<int, Set<String>> _knownByTicket = <int, Set<String>>{};
  final Map<int, int> _unreadByTicket = <int, int>{};
  Set<String> _activeKnown = <String>{};

  List<Map<String, dynamic>> _tickets = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _filtered = <Map<String, dynamic>>[];
  Map<String, dynamic>? _active;

  Timer? _listPoll;
  Timer? _threadPoll;

  bool _loadingList = true;
  bool _loadingThread = false;
  bool _sending = false;
  bool _statusSaving = false;
  bool _soundEnabled = true;
  bool _internalNote = false;
  bool _desktopListVisible = true;
  bool _mobileThreadOpen = false;
  bool _booted = false;
  final int _page = 1;
  int _newIndicator = 0;
  String _statusFilter = 'all';
  bool get _supportsAudioPlayer =>
      !kIsWeb && defaultTargetPlatform != TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilters);
    _threadScroll.addListener(_onThreadScroll);
    _prepareAudio();
    _loadTickets(showLoader: true, fromPolling: false);
    _listPoll = Timer.periodic(_listPollInterval, (_) {
      _loadTickets(showLoader: false, fromPolling: true);
    });
  }

  @override
  void dispose() {
    _listPoll?.cancel();
    _listPoll = null;
    _threadPoll?.cancel();
    _threadPoll = null;
    _audioPlayer?.dispose();
    _searchCtrl.removeListener(_applyFilters);
    _searchCtrl.dispose();
    _replyCtrl.dispose();
    _threadScroll.removeListener(_onThreadScroll);
    _threadScroll.dispose();
    super.dispose();
  }

  Future<void> _prepareAudio() async {
    if (!_supportsAudioPlayer) return;
    final player = AudioPlayer();
    _audioPlayer = player;
    try {
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setVolume(1.0);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource('sounds/bildirim.wav'));
    } catch (_) {}
  }

  Future<void> _playSound() async {
    if (!_soundEnabled) return;
    final player = _audioPlayer;
    if (player == null) {
      SystemSound.play(SystemSoundType.alert);
      return;
    }
    try {
      await player.setVolume(1.0);
      await player.stop();
      await player.play(AssetSource('sounds/bildirim.wav'), volume: 1.0);
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  String _normalizeStatus(dynamic value) {
    final raw = '${value ?? ''}'.trim().toLowerCase();
    if (raw.isEmpty) return 'open';
    if (raw == 'active' || raw == 'open') return 'open';
    if (raw == 'waiting' || raw == 'in_progress' || raw == 'in-progress') {
      return 'pending';
    }
    if (raw == 'resolved' || raw == 'closed') return 'closed';
    return raw;
  }

  bool _matchesStatusFilter(String ticketStatus, String filterStatus) {
    final filter = _normalizeStatus(filterStatus);
    if (filter == 'all') return true;
    return _normalizeStatus(ticketStatus) == filter;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final t = '$value'.trim().toLowerCase();
    return t == '1' || t == 'true' || t == 'yes' || t == 'on';
  }

  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    final t = '$value'.trim();
    if (t.isEmpty) return null;
    return DateTime.tryParse(t) ?? DateTime.tryParse(t.replaceAll('/', '-'));
  }

  String _cleanBody(String input) {
    return input
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll(RegExp(r'\r\n|\r'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
  }

  Map<String, dynamic> _parseMessage(Map<String, dynamic> raw, int index) {
    final id = _toInt(raw['id']);
    final type = '${raw['sender_type'] ?? raw['from'] ?? raw['type'] ?? 'user'}'
        .toLowerCase();
    final name =
        '${raw['sender_name'] ?? raw['name'] ?? raw['display_name'] ?? (type == 'operator' || type == 'admin' ? 'Admin' : 'Musteri')}';
    final body = _cleanBody(
        '${raw['message'] ?? raw['body'] ?? raw['text'] ?? raw['content'] ?? ''}');
    final date = _toDate(raw['date'] ?? raw['created_at'] ?? raw['time']);
    final internal = _toBool(raw['is_internal']) ||
        _toBool(raw['internal']) ||
        _toBool(raw['is_note']);
    final key = id > 0
        ? 'id:$id'
        : 'raw:$type:${date?.toIso8601String() ?? ''}:${body.hashCode}:$index';
    return <String, dynamic>{
      ...raw,
      'id': id,
      'key': key,
      'sender_type': type,
      'sender_name': name,
      'body': body,
      'created_at': date,
      'is_internal': internal,
    };
  }

  Map<String, dynamic> _parseTicket(Map<String, dynamic> raw) {
    final id = _toInt(raw['id']);
    final root =
        _cleanBody('${raw['message'] ?? raw['body'] ?? raw['text'] ?? ''}');
    final rawReplies = (raw['replies'] as List<dynamic>?) ??
        (raw['messages'] as List<dynamic>?) ??
        const <dynamic>[];
    final messages = <Map<String, dynamic>>[];
    if (root.isNotEmpty) {
      messages.add(<String, dynamic>{
        'id': 0,
        'key': 'root:$id:${root.hashCode}',
        'sender_type': 'user',
        'sender_name':
            '${raw['user_name'] ?? raw['customer_name'] ?? 'Musteri'}',
        'body': root,
        'created_at': _toDate(raw['created_at']),
        'is_internal': false,
      });
    }
    for (var i = 0; i < rawReplies.length; i++) {
      messages.add(_parseMessage(rawReplies[i] as Map<String, dynamic>, i));
    }
    messages.sort((a, b) {
      final ad = (a['created_at'] as DateTime?)?.millisecondsSinceEpoch ?? 0;
      final bd = (b['created_at'] as DateTime?)?.millisecondsSinceEpoch ?? 0;
      return ad.compareTo(bd);
    });
    return <String, dynamic>{
      ...raw,
      'id': id,
      'ticket_no': '${raw['ticket_no'] ?? raw['number'] ?? '#$id'}',
      'subject': '${raw['subject'] ?? raw['title'] ?? '-'}',
      'status': _normalizeStatus(raw['status']),
      'priority': '${raw['priority'] ?? 'normal'}'.toLowerCase(),
      'customer_name':
          '${raw['user_name'] ?? raw['customer_name'] ?? raw['name'] ?? 'Musteri'}',
      'customer_email':
          '${raw['email'] ?? raw['user_email'] ?? raw['customer_email'] ?? '-'}',
      'created_at_dt': _toDate(raw['created_at']),
      'updated_at_dt': _toDate(
          raw['updated_at'] ?? raw['last_reply_at'] ?? raw['created_at']),
      'messages': messages,
    };
  }

  Future<void> _loadTickets(
      {required bool showLoader, required bool fromPolling}) async {
    if (showLoader && mounted) {
      setState(() => _loadingList = true);
    }
    try {
      final payload = await _api.getSupportTickets(page: _page, perPage: 100);
      final items = (payload['items'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => _parseTicket(e as Map<String, dynamic>))
          .toList();
      _detectIncoming(items, fromPolling: fromPolling);
      _tickets = items;
      final activeId = _toInt(_active?['id']);
      if (activeId > 0) {
        final found = items.where((t) => _toInt(t['id']) == activeId).toList();
        if (found.isNotEmpty) {
          _mergeActive(found.first, fromPolling: fromPolling);
        }
      }
      _booted = true;
      _applyFilters();
      if (showLoader && mounted) setState(() => _loadingList = false);
    } catch (e) {
      if (mounted) setState(() => _loadingList = false);
      if (!fromPolling) _snack('Ticketlar yuklenemedi: $e', AppTheme.error);
    }
  }

  void _detectIncoming(List<Map<String, dynamic>> fresh,
      {required bool fromPolling}) {
    var incoming = 0;
    for (final ticket in fresh) {
      final id = _toInt(ticket['id']);
      final msgs =
          (ticket['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
      final current = msgs.map((m) => '${m['key']}').toSet();
      final known = _knownByTicket[id] ?? <String>{};
      if (_booted) {
        final appended = current.difference(known);
        if (appended.isNotEmpty) {
          final userAdd = msgs
              .where((m) => appended.contains('${m['key']}'))
              .where((m) => !_isOperatorMessageType('${m['sender_type']}'))
              .length;
          if (userAdd > 0 && _toInt(_active?['id']) != id) {
            _unreadByTicket[id] = (_unreadByTicket[id] ?? 0) + userAdd;
            incoming += userAdd;
          }
        }
      }
      _knownByTicket[id] = current;
    }
    if (incoming > 0 && fromPolling) {
      _playSound();
      _snack('$incoming yeni musteri mesaji geldi.', AppTheme.info);
    }
  }

  bool _isOperatorMessageType(String rawType) {
    final type = rawType.toLowerCase().trim();
    return [
      'admin',
      'operator',
      'support',
      'staff',
      'message',
      'note',
      'lineitem',
      'system',
      'bot',
    ].contains(type);
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _tickets.where((t) {
      if (!_matchesStatusFilter('${t['status']}', _statusFilter)) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay =
          '${t['ticket_no']} ${t['subject']} ${t['customer_name']} ${t['customer_email']}'
              .toLowerCase();
      return hay.contains(q);
    }).toList();
    // Sadece liste gerçekten değiştiyse yeniden çiz
    if (filtered.length == _filtered.length) {
      var same = true;
      for (var i = 0; i < filtered.length; i++) {
        if (_toInt(filtered[i]['id']) != _toInt(_filtered[i]['id'])) {
          same = false;
          break;
        }
      }
      if (same) return;
    }
    if (mounted) setState(() => _filtered = filtered);
  }

  Future<void> _openTicket(Map<String, dynamic> ticket, bool compact) async {
    _active = ticket;
    _activeKnown =
        ((ticket['messages'] as List<dynamic>).cast<Map<String, dynamic>>())
            .map((m) => '${m['key']}')
            .toSet();
    _newIndicator = 0;
    _unreadByTicket[_toInt(ticket['id'])] = 0;
    if (compact) _mobileThreadOpen = true;
    if (mounted) setState(() {});
    _markRead();
    _threadPoll?.cancel();
    _threadPoll = Timer.periodic(_threadPollInterval, (_) {
      _refreshActive(fromPolling: true);
    });
    await _refreshActive(fromPolling: false);
  }

  Future<void> _markRead() async {
    final id = _toInt(_active?['id']);
    if (id <= 0) return;
    try {
      await _api.markSupportTicketRead(id);
    } catch (_) {}
  }

  Future<void> _refreshActive({required bool fromPolling}) async {
    final id = _toInt(_active?['id']);
    if (id <= 0) return;
    if (!fromPolling && mounted) setState(() => _loadingThread = true);
    try {
      final sinceId = _lastKnownMessageId();
      final payload = await _api.getSupportTicketUpdates(id, sinceId: sinceId);
      final raw =
          (payload['ticket'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      if (raw.isEmpty) return;
      _mergeActive(_parseTicket(raw), fromPolling: fromPolling);
      _unreadByTicket[id] = 0;
    } catch (e) {
      if (!fromPolling) _snack('Konusma yenilenemedi: $e', AppTheme.error);
    } finally {
      if (!fromPolling && mounted) setState(() => _loadingThread = false);
    }
  }

  void _mergeActive(Map<String, dynamic> fresh, {required bool fromPolling}) {
    final old = _active;
    if (old == null || _toInt(old['id']) != _toInt(fresh['id'])) {
      _active = fresh;
      _activeKnown =
          ((fresh['messages'] as List<dynamic>).cast<Map<String, dynamic>>())
              .map((m) => '${m['key']}')
              .toSet();
      if (mounted) setState(() {});
      _scrollBottom(immediate: true);
      return;
    }
    final nearBottom = _isNearBottom();
    final msgs =
        ((fresh['messages'] as List<dynamic>).cast<Map<String, dynamic>>());
    final freshKeys = msgs.map((m) => '${m['key']}').toSet();
    final appended = freshKeys.difference(_activeKnown);
    _active = fresh;
    _activeKnown = freshKeys;
    // Ses ve bildirim sadece _detectIncoming() tarafından üretilir.
    // _mergeActive'den tekrar çalmak duplicate'e neden oluyordu.

    // Yeni mesaj yoksa setState çağırma — gereksiz yeniden çizimi önler
    if (appended.isEmpty) return;

    if (!nearBottom) {
      _newIndicator += appended.length;
    } else {
      _newIndicator = 0;
    }
    if (mounted) setState(() {});
    if (nearBottom) _scrollBottom(immediate: false);
  }

  int _lastKnownMessageId() {
    final active = _active;
    if (active == null) return 0;
    final messages = (active['messages'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>();
    var maxId = 0;
    for (final message in messages) {
      final id = _toInt(message['id']);
      if (id > maxId) maxId = id;
    }
    return maxId;
  }

  bool _isNearBottom() {
    if (!_threadScroll.hasClients) return true;
    final p = _threadScroll.position;
    return (p.maxScrollExtent - p.pixels) < 72;
  }

  void _onThreadScroll() {
    if (_newIndicator <= 0) return;
    if (_isNearBottom() && mounted) setState(() => _newIndicator = 0);
  }

  // ─── DÜZELTME: mounted guard eklendi → _dependents.isEmpty crash'ini önler ─
  void _scrollBottom({required bool immediate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_threadScroll.hasClients) return;
      final max = _threadScroll.position.maxScrollExtent;
      if (immediate) {
        _threadScroll.jumpTo(max);
      } else {
        _threadScroll.animateTo(max,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendReply() async {
    final id = _toInt(_active?['id']);
    final text = _replyCtrl.text.trim();
    if (id <= 0 || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _api.replySupportTicket(id, text, internal: _internalNote);
      _replyCtrl.clear();
      _internalNote = false;
      if (mounted) setState(() {});
      await _refreshActive(fromPolling: false);
      _snack('Yanit gonderildi.', AppTheme.success);
    } catch (e) {
      _snack('Yanit gonderilemedi: $e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveStatus(String status) async {
    final id = _toInt(_active?['id']);
    if (id <= 0 || _statusSaving) return;
    final old = '${_active?['status'] ?? 'open'}';
    if (old == status) return;
    setState(() {
      _statusSaving = true;
      _active = <String, dynamic>{...?_active, 'status': status};
    });
    try {
      await _api.updateSupportTicketStatus(id, status);
      await _refreshActive(fromPolling: false);
      _snack('Durum guncellendi.', AppTheme.success);
    } catch (e) {
      setState(() => _active = <String, dynamic>{...?_active, 'status': old});
      _snack('Durum kaydi basarisiz: $e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _statusSaving = false);
    }
  }

  String _fmt(DateTime? d) => d == null ? '-' : _df.format(d.toLocal());

  String _ago(DateTime? d) {
    if (d == null) return '-';
    final diff = DateTime.now().difference(d.toLocal());
    if (diff.inSeconds < 30) return 'simdi';
    if (diff.inMinutes < 1) return '${diff.inSeconds} sn once';
    if (diff.inHours < 1) return '${diff.inMinutes} dk once';
    if (diff.inDays < 1) return '${diff.inHours} sa once';
    if (diff.inDays < 7) return '${diff.inDays} gun once';
    return _fmt(d);
  }

  int get _totalUnread => _unreadByTicket.values.fold<int>(0, (a, b) => a + b);

  void _snack(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(text),
          backgroundColor: color,
          duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final compact = c.maxWidth < 960;
      return Column(children: [
        _buildToolbar(compact),
        Expanded(
          child: compact
              ? (_mobileThreadOpen && _active != null
                  ? _buildThread(true)
                  : _buildList(true))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Row(children: [
                    if (_desktopListVisible)
                      SizedBox(
                          width: (c.maxWidth * .36).clamp(320, 450),
                          child: _buildList(false)),
                    if (_desktopListVisible) const SizedBox(width: 10),
                    Expanded(child: _buildThread(false)),
                  ]),
                ),
        ),
      ]);
    });
  }

  Widget _buildToolbar(bool compact) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.glassDecoration(radius: 16),
          child: LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 560;
              final chips = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('Toplam', _tickets.length, AppTheme.info),
                  _chip(
                    'Acik',
                    _tickets.where((t) => '${t['status']}' == 'open').length,
                    AppTheme.warning,
                  ),
                  _chip('Yeni', _totalUnread, AppTheme.primaryLight),
                ],
              );

              Widget actionButton({
                required VoidCallback onPressed,
                required Widget icon,
                String? tooltip,
              }) {
                return IconButton(
                  onPressed: onPressed,
                  tooltip: tooltip,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 36, height: 36),
                  padding: EdgeInsets.zero,
                  icon: icon,
                );
              }

              final actions = Wrap(
                spacing: 4,
                children: [
                  actionButton(
                    onPressed: () =>
                        _loadTickets(showLoader: true, fromPolling: false),
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Yenile',
                  ),
                  actionButton(
                    onPressed: () =>
                        setState(() => _soundEnabled = !_soundEnabled),
                    icon: Icon(_soundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded),
                    tooltip: _soundEnabled ? 'Sesi Kapat' : 'Sesi Ac',
                  ),
                  if (!compact)
                    actionButton(
                      onPressed: () => setState(
                          () => _desktopListVisible = !_desktopListVisible),
                      icon: Icon(_desktopListVisible
                          ? Icons.view_sidebar_rounded
                          : Icons.view_sidebar_outlined),
                      tooltip: _desktopListVisible
                          ? 'Listeyi Gizle'
                          : 'Listeyi Goster',
                    ),
                ],
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    chips,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: chips),
                  const SizedBox(width: 8),
                  actions,
                ],
              );
            },
          ),
        ),
      );

  Widget _chip(String t, int v, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .4)),
        ),
        child: Text('$t: $v',
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      );

  Widget _buildList(bool compact) => Container(
        margin: compact
            ? const EdgeInsets.fromLTRB(14, 0, 14, 12)
            : EdgeInsets.zero,
        decoration: AppTheme.glassDecoration(radius: 16),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 420;
                final searchField = TextField(
                  controller: _searchCtrl,
                  decoration: AppTheme.inputDecoration(
                    hint: 'Ticket, musteri, email ara...',
                    prefixIcon: Icons.search_rounded,
                  ),
                );
                final statusDropdown = DropdownButtonFormField<String>(
                  key: ValueKey<String>('filter-$_statusFilter'),
                  initialValue: _statusFilter,
                  decoration: AppTheme.inputDecoration(hint: 'Durum'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tum')),
                    DropdownMenuItem(value: 'open', child: Text('Acik')),
                    DropdownMenuItem(
                        value: 'pending', child: Text('Beklemede')),
                    DropdownMenuItem(
                        value: 'in_progress', child: Text('Islemde')),
                    DropdownMenuItem(value: 'resolved', child: Text('Cozuldu')),
                    DropdownMenuItem(value: 'closed', child: Text('Kapali')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _statusFilter = v);
                    _applyFilters();
                  },
                );

                if (narrow) {
                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      statusDropdown,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 8),
                    SizedBox(width: 140, child: statusDropdown),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppTheme.glassBorder),
          Expanded(
            child: _loadingList
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _filtered.isEmpty
                    ? const Center(
                        child: Text('Ticket bulunamadi',
                            style: TextStyle(color: AppTheme.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final t = _filtered[i];
                          final id = _toInt(t['id']);
                          final unread = _unreadByTicket[id] ?? 0;
                          final active = _toInt(_active?['id']) == id;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openTicket(t, compact),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppTheme.primary.withValues(alpha: .14)
                                    : AppTheme.glassBg.withValues(alpha: .24),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: active
                                        ? AppTheme.primary
                                            .withValues(alpha: .55)
                                        : AppTheme.glassBorder),
                              ),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                          child: Text('${t['ticket_no']}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.textMuted))),
                                      if (unread > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.warning
                                                .withValues(alpha: .2),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text('$unread',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppTheme.warning,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                    ]),
                                    const SizedBox(height: 6),
                                    Text('${t['subject']}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                        '${t['customer_name']} • ${t['customer_email']}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textMuted)),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      StatusBadge(
                                          status: '${t['status']}',
                                          fontSize: 9),
                                      const Spacer(),
                                      Text(
                                          _ago(t['updated_at_dt'] as DateTime?),
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.textMuted)),
                                    ]),
                                  ]),
                            ),
                          );
                        },
                      ),
          ),
        ]),
      );

  Widget _buildThread(bool compact) {
    final active = _active;
    if (active == null) {
      return Container(
        margin: compact
            ? const EdgeInsets.fromLTRB(14, 0, 14, 12)
            : EdgeInsets.zero,
        decoration: AppTheme.glassDecoration(radius: 16),
        child: const Center(
            child: Text('Ticket secin',
                style: TextStyle(color: AppTheme.textMuted))),
      );
    }
    final msgs =
        (active['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      margin:
          compact ? const EdgeInsets.fromLTRB(14, 0, 14, 12) : EdgeInsets.zero,
      decoration: AppTheme.glassDecoration(radius: 16),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: LayoutBuilder(
            builder: (context, hc) {
              final narrowHeader = compact && hc.maxWidth < 620;
              final statusDropdown = SizedBox(
                width: narrowHeader ? double.infinity : 150,
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                      'status-${active['id']}-${active['status']}'),
                  initialValue: '${active['status']}',
                  decoration: AppTheme.inputDecoration(hint: 'Durum'),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Acik')),
                    DropdownMenuItem(
                        value: 'pending', child: Text('Beklemede')),
                    DropdownMenuItem(
                        value: 'in_progress', child: Text('Islemde')),
                    DropdownMenuItem(value: 'resolved', child: Text('Cozuldu')),
                    DropdownMenuItem(value: 'closed', child: Text('Kapali')),
                  ],
                  onChanged: _statusSaving
                      ? null
                      : (v) => v == null ? null : _saveStatus(v),
                ),
              );
              final titleBlock = Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${active['subject']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(
                          '${active['ticket_no']} • ${active['customer_name']} • ${active['customer_email']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                    ]),
              );
              if (narrowHeader) {
                return Column(
                  children: [
                    Row(children: [
                      if (compact)
                        IconButton(
                          onPressed: () =>
                              setState(() => _mobileThreadOpen = false),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      titleBlock,
                    ]),
                    const SizedBox(height: 8),
                    statusDropdown,
                  ],
                );
              }
              return Row(children: [
                if (compact)
                  IconButton(
                    onPressed: () => setState(() => _mobileThreadOpen = false),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                titleBlock,
                const SizedBox(width: 8),
                statusDropdown,
              ]);
            },
          ),
        ),
        const Divider(height: 1, color: AppTheme.glassBorder),
        Expanded(
          child: Stack(children: [
            if (_loadingThread && msgs.isEmpty)
              const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
            else
              ListView.builder(
                controller: _threadScroll,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                itemCount: msgs.length,
                itemBuilder: (context, i) {
                  final m = msgs[i];
                  final type = '${m['sender_type']}'.toLowerCase();
                  final isAdmin = [
                    'admin', 'operator', 'support', 'staff',
                    'message', 'note', 'lineitem', 'system', 'bot',
                  ].contains(type);
                  final isInternal = _toBool(m['is_internal']);
                  final isNote = type == 'note' || isInternal;
                  final body = '${m['body']}';
                  final senderName = '${m['sender_name']}';
                  final date = _fmt(m['created_at'] as DateTime?);

                  // Yönetim paneli: Admin mesajları SAĞDA, müşteri SOLDA
                  final align = isAdmin
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start;

                  // Renk paleti
                  final Color bubbleBg;
                  final Color textColor;
                  final Color metaColor;
                  final Color senderColor;
                  final BorderRadius bubbleRadius;

                  if (isNote) {
                    bubbleBg = AppTheme.warning.withValues(alpha: .12);
                    textColor = AppTheme.warning;
                    metaColor = AppTheme.warning.withValues(alpha: .6);
                    senderColor = AppTheme.warning;
                    bubbleRadius = BorderRadius.circular(16);
                  } else if (isAdmin) {
                    bubbleBg = AppTheme.primary.withValues(alpha: .22);
                    textColor = Colors.white;
                    metaColor = AppTheme.textMuted;
                    senderColor = AppTheme.primaryLight;
                    bubbleRadius = const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    );
                  } else {
                    bubbleBg = AppTheme.glassBg.withValues(alpha: .32);
                    textColor = AppTheme.textPrimary;
                    metaColor = AppTheme.textMuted;
                    senderColor = AppTheme.textSecondary;
                    bubbleRadius = const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(18),
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: 6,
                      left: isAdmin ? 48 : 0,
                      right: isAdmin ? 0 : 48,
                    ),
                    child: Column(
                      crossAxisAlignment: align,
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxWidth: 520),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          decoration: BoxDecoration(
                            color: bubbleBg,
                            borderRadius: bubbleRadius,
                            border: Border.all(
                              color: isNote
                                  ? AppTheme.warning.withValues(alpha: .3)
                                  : isAdmin
                                      ? AppTheme.primary.withValues(alpha: .3)
                                      : AppTheme.glassBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isNote
                                        ? Icons.sticky_note_2_rounded
                                        : isAdmin
                                            ? Icons.support_agent_rounded
                                            : Icons.person_rounded,
                                    size: 13,
                                    color: senderColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      isAdmin ? (senderName.isNotEmpty ? senderName : 'Admin') : senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: senderColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isNote)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warning.withValues(alpha: .25),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text('İÇ NOT',
                                          style: TextStyle(
                                              fontSize: 8,
                                              color: AppTheme.warning,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: .5)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                body,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.4,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                date,
                                style: TextStyle(fontSize: 10, color: metaColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (_newIndicator > 0)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      _scrollBottom(immediate: false);
                      setState(() => _newIndicator = 0);
                    },
                    icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                    label: Text('$_newIndicator yeni mesaj'),
                  ),
                ),
              ),
          ]),
        ),
        AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(bottom: bottomInset > 0 ? 6 : 0),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              border: const Border(
                  top: BorderSide(color: AppTheme.glassBorder)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .2),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Mesaj yazma satırı
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyCtrl,
                          minLines: 1,
                          maxLines: 5,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: 'Yanıtınızı yazın...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textMuted.withValues(alpha: .6),
                            ),
                            filled: true,
                            fillColor: AppTheme.glassBg.withValues(alpha: .3),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(
                                  color: AppTheme.glassBorder.withValues(alpha: .4)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(
                                  color: AppTheme.glassBorder.withValues(alpha: .4)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide(
                                  color: AppTheme.primary.withValues(alpha: .6)),
                            ),
                          ),
                          onSubmitted: (_) {
                            if (_sending) return;
                            _sendReply();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Gönder butonu
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Material(
                          color: _sending
                              ? AppTheme.warning.withValues(alpha: .5)
                              : AppTheme.warning,
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: _sending ? null : _sendReply,
                            child: Center(
                              child: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.bgDark,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded,
                                      size: 20, color: AppTheme.bgDark),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Alt seçenekler
                  Row(
                    children: [
                      _toggleChip(
                        label: 'İç not',
                        icon: Icons.sticky_note_2_outlined,
                        active: _internalNote,
                        activeColor: AppTheme.warning,
                        onTap: () =>
                            setState(() => _internalNote = !_internalNote),
                      ),
                      const SizedBox(width: 8),
                      _toggleChip(
                        label: 'Ses bildirimi',
                        icon: _soundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        active: _soundEnabled,
                        activeColor: AppTheme.success,
                        onTap: () =>
                            setState(() => _soundEnabled = !_soundEnabled),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _toggleChip({
    required String label,
    required IconData icon,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: .15)
              : AppTheme.glassBg.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? activeColor.withValues(alpha: .4)
                : AppTheme.glassBorder.withValues(alpha: .3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: active ? activeColor : AppTheme.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? activeColor : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
