import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/admin_api.dart';

// ─── Kampanya şablonları ───────────────────────────────────────────────────
const List<Map<String, dynamic>> _kCampaignTemplates = [
  {
    'id': 'indirim',
    'label': '🏷️ İndirim',
    'color': 0xFFE53935,
    'title': '🔥 Özel İndirim Fırsatı!',
    'description': 'Seçili servislerimizde sınırlı süre için özel fiyatlar sizi bekliyor.',
    'details': '⏰ Kampanya süresi dolmadan avantajlı fiyatlardan yararlanın.',
    'cta_label': 'Hemen Sipariş Ver',
  },
  {
    'id': 'yeni_servis',
    'label': '✨ Yeni Servis',
    'color': 0xFF6200EA,
    'title': '✨ Yeni Servis Geldi!',
    'description': 'Platformumuza eklenen yeni servisi keşfet ve ilk siparişini ver.',
    'details': 'Yeni servisimiz kullanıcılarımıza özel avantajlı fiyatla sunulmaktadır.',
    'cta_label': 'Servisi Keşfet',
  },
  {
    'id': 'sezon',
    'label': '🎉 Sezon',
    'color': 0xFFFF6F00,
    'title': '🎉 Sezon Kampanyası Başladı!',
    'description': 'Sezonun en büyük kampanyasıyla büyük tasarruf fırsatını kaçırma.',
    'details': 'Kampanya stoklarla sınırlıdır. Erken davranın!',
    'cta_label': 'Kampanyayı Gör',
  },
  {
    'id': 'bos',
    'label': '📝 Boş',
    'color': 0xFF37474F,
    'title': '',
    'description': '',
    'details': '',
    'cta_label': '',
  },
];

class NotificationsCampaignTab extends StatefulWidget {
  const NotificationsCampaignTab({super.key});

  @override
  State<NotificationsCampaignTab> createState() => _NotificationsCampaignTabState();
}

class _NotificationsCampaignTabState extends State<NotificationsCampaignTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loadingNotifications = true;
  bool _loadingCampaigns = true;
  bool _loadingServices = true;
  bool _actionLoading = false;

  bool _notificationsSupported = true;
  bool _campaignsSupported = true;

  bool _notificationFormOpen = false;
  bool _campaignFormOpen = false;

  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _services = [];

  final _notificationTitleCtrl = TextEditingController();
  final _notificationBodyCtrl = TextEditingController();
  final _notificationActionCtrl = TextEditingController();

  final _campaignTitleCtrl = TextEditingController();
  final _campaignDescriptionCtrl = TextEditingController();
  final _campaignDetailsCtrl = TextEditingController();
  final _campaignCtaLabelCtrl = TextEditingController();
  final _campaignCtaUrlCtrl = TextEditingController();
  final _campaignCoverImageCtrl = TextEditingController();
  final _campaignIconCtrl = TextEditingController();
  bool _campaignActive = true;
  int? _selectedServiceId;
  String _selectedServiceName = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationTitleCtrl.dispose();
    _notificationBodyCtrl.dispose();
    _notificationActionCtrl.dispose();
    _campaignTitleCtrl.dispose();
    _campaignDescriptionCtrl.dispose();
    _campaignDetailsCtrl.dispose();
    _campaignCtaLabelCtrl.dispose();
    _campaignCtaUrlCtrl.dispose();
    _campaignCoverImageCtrl.dispose();
    _campaignIconCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadNotifications(), _loadCampaigns(), _loadServices()]);
  }

  Future<void> _loadNotifications() async {
    setState(() => _loadingNotifications = true);
    try {
      final data = await AdminApi().getNotifications(page: 1);
      final rawItems = (data['items'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _notifications = rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _notificationsSupported = data['supported'] != false;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loadingNotifications = false);
    }
  }

  Future<void> _loadCampaigns() async {
    setState(() => _loadingCampaigns = true);
    try {
      final data = await AdminApi().getCampaigns(page: 1);
      final rawItems = (data['items'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _campaigns = rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _campaignsSupported = data['supported'] != false;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _loadingCampaigns = false);
    }
  }

  Future<void> _loadServices() async {
    setState(() => _loadingServices = true);
    try {
      final data = await AdminApi().getServices(page: 1, active: '1');
      final rawItems = (data['items'] as List?) ?? const [];
      final items = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => _readServiceId(e) > 0)
          .toList();
      if (!mounted) return;
      setState(() => _services = items);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Servis listesi alınamadı: $e', AppTheme.warning);
    } finally {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  Future<void> _sendNotification() async {
    if (!_notificationsSupported) {
      _showSnack('Bildirim servisi bu sunucuda aktif değil.', AppTheme.warning);
      return;
    }
    final title = _notificationTitleCtrl.text.trim();
    final body = _notificationBodyCtrl.text.trim();
    final actionUrl = _notificationActionCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _showSnack('Başlık ve mesaj zorunludur.', AppTheme.warning);
      return;
    }
    setState(() => _actionLoading = true);
    try {
      await AdminApi().sendNotification({
        'title': title,
        'message': body,
        'audience': 'all',
        if (actionUrl.isNotEmpty) 'action': actionUrl,
      });
      if (!mounted) return;
      _notificationTitleCtrl.clear();
      _notificationBodyCtrl.clear();
      _notificationActionCtrl.clear();
      setState(() => _notificationFormOpen = false);
      _showSnack('✅ Bildirim gönderildi.', AppTheme.success);
      await _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _saveCampaign() async {
    if (!_campaignsSupported) {
      _showSnack('Kampanya servisi bu sunucuda aktif değil.', AppTheme.warning);
      return;
    }
    final title = _campaignTitleCtrl.text.trim();
    final description = _campaignDescriptionCtrl.text.trim();
    if (title.isEmpty || description.isEmpty) {
      _showSnack('Başlık ve açıklama zorunludur.', AppTheme.warning);
      return;
    }
    if ((_selectedServiceId ?? 0) <= 0) {
      _showSnack('Servis seçmelisiniz.', AppTheme.warning);
      return;
    }
    setState(() => _actionLoading = true);
    try {
      final coverImage = _campaignCoverImageCtrl.text.trim();
      final icon = _campaignIconCtrl.text.trim();
      await AdminApi().createCampaign({
        'title': title,
        'description': description,
        'details': _campaignDetailsCtrl.text.trim(),
        'cta_label': _campaignCtaLabelCtrl.text.trim(),
        'cta_url': _campaignCtaUrlCtrl.text.trim(),
        'is_active': _campaignActive ? 1 : 0,
        'active': _campaignActive ? 1 : 0,
        'service_id': _selectedServiceId,
        'service_name': _selectedServiceName,
        if (coverImage.isNotEmpty) 'cover_image': coverImage,
        if (coverImage.isNotEmpty) 'image': coverImage,
        if (coverImage.isNotEmpty) 'media_url': coverImage,
        if (icon.isNotEmpty) 'icon': icon,
        if (icon.isNotEmpty) 'icon_url': icon,
      });
      if (!mounted) return;
      _campaignTitleCtrl.clear();
      _campaignDescriptionCtrl.clear();
      _campaignDetailsCtrl.clear();
      _campaignCtaLabelCtrl.clear();
      _campaignCtaUrlCtrl.clear();
      _campaignCoverImageCtrl.clear();
      _campaignIconCtrl.clear();
      setState(() {
        _selectedServiceId = null;
        _selectedServiceName = '';
        _campaignActive = true;
        _campaignFormOpen = false;
      });
      _showSnack('✅ Kampanya kaydedildi.', AppTheme.success);
      await _loadCampaigns();
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e', AppTheme.error);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _toggleCampaignActive(Map<String, dynamic> item, bool active) async {
    final id = _readCampaignId(item);
    if (id <= 0) return;
    try {
      await AdminApi().updateCampaign(id, {'is_active': active ? 1 : 0, 'active': active ? 1 : 0});
      await _loadCampaigns();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Durum güncellenemedi: $e', AppTheme.error);
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> item) async {
    final id = int.tryParse('${item['id'] ?? ''}') ?? 0;
    if (id <= 0) return;
    final confirmed = await _showDeleteDialog(
      title: 'Bildirimi Sil',
      content: '"${item['title'] ?? 'Bu bildirim'}" kalıcı olarak silinecek.',
    );
    if (confirmed != true) return;
    try {
      await AdminApi().deleteNotification(id);
      await _loadNotifications();
      if (!mounted) return;
      _showSnack('Bildirim silindi.', AppTheme.success);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Silinemedi: $e', AppTheme.error);
    }
  }

  Future<void> _deleteCampaign(Map<String, dynamic> item) async {
    final id = _readCampaignId(item);
    if (id <= 0) return;
    final confirmed = await _showDeleteDialog(
      title: 'Kampanyayı Sil',
      content: '"${item['title'] ?? 'Bu kampanya'}" kalıcı olarak silinecek.',
    );
    if (confirmed != true) return;
    try {
      await AdminApi().deleteCampaign(id);
      await _loadCampaigns();
      if (!mounted) return;
      _showSnack('Kampanya silindi.', AppTheme.success);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Silinemedi: $e', AppTheme.error);
    }
  }

  Future<bool?> _showDeleteDialog({required String title, required String content}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF111827),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: AppTheme.error, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
        content: Text(content,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Sil', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _applyTemplate(Map<String, dynamic> tpl) {
    setState(() {
      _campaignTitleCtrl.text = tpl['title'] as String;
      _campaignDescriptionCtrl.text = tpl['description'] as String;
      _campaignDetailsCtrl.text = tpl['details'] as String;
      _campaignCtaLabelCtrl.text = tpl['cta_label'] as String;
      _campaignFormOpen = true;
    });
  }

  // ─── Yardımcılar ─────────────────────────────────────────────────────────
  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '$value'.trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'on' || text == 'active';
  }

  int _readServiceId(Map<String, dynamic> item) {
    final raw = item['id'] ?? item['service_id'] ?? item['provider_service_id'];
    return int.tryParse('$raw') ?? 0;
  }

  int _readCampaignId(Map<String, dynamic> item) {
    final raw = item['id'] ?? item['campaign_id'];
    return int.tryParse('$raw') ?? 0;
  }

  String _readServiceName(Map<String, dynamic> item) {
    final name = '${item['name'] ?? item['service_name'] ?? item['title'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    final id = _readServiceId(item);
    return id > 0 ? 'Servis #$id' : '-';
  }

  bool _isInvalidDate(String value) {
    final text = value.trim().toLowerCase();
    return text.isEmpty ||
        text == 'null' ||
        text == 'none' ||
        text.startsWith('0000-00-00') ||
        text.startsWith('1970-01-01') ||
        text == '0' ||
        text == '-';
  }

  /// Tarihi sadece "YYYY-MM-DD" formatına kırpar, saat kısmını atar
  String _formatDate(String raw) {
    final text = raw.trim();
    // "2025-06-01 00:00:00" → "2025-06-01"
    if (text.contains(' ')) return text.split(' ').first;
    if (text.contains('T')) return text.split('T').first;
    return text;
  }

  String _campaignRange(Map<String, dynamic> item) {
    final rawStart = '${item['start_at'] ?? item['start_date'] ?? ''}';
    final rawEnd   = '${item['end_at']   ?? item['end_date']   ?? ''}';
    final start = _isInvalidDate(rawStart) ? '' : _formatDate(rawStart);
    final end   = _isInvalidDate(rawEnd)   ? '' : _formatDate(rawEnd);
    if (start.isEmpty && end.isEmpty) return '';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start → $end';
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  // =========================================================================
  //  BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─── Tab Bar ─────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1526),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight]),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textMuted,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notifications_rounded, size: 16),
                    const SizedBox(width: 6),
                    const Text('Bildirimler'),
                    if (_notifications.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _countBadge(_notifications.length),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.campaign_rounded, size: 16),
                    const SizedBox(width: 6),
                    const Text('Kampanyalar'),
                    if (_campaigns.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _countBadge(_campaigns.length),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildNotificationsView(), _buildCampaignsView()],
          ),
        ),
      ],
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$count',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }

  // ─── Bildirimler görünümü ─────────────────────────────────────────────────
  Widget _buildNotificationsView() {
    if (!_loadingNotifications && !_notificationsSupported) {
      return _buildInfoState(Icons.notifications_off_rounded, 'Bildirim servisi bu sunucuda aktif değil.');
    }
    return Column(
      children: [
        _buildActionHeader(
          icon: Icons.send_rounded,
          label: 'Yeni Bildirim Gönder',
          isOpen: _notificationFormOpen,
          accentColor: AppTheme.primary,
          onTap: () => setState(() => _notificationFormOpen = !_notificationFormOpen),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: _notificationFormOpen ? _buildNotificationComposer() : const SizedBox.shrink(),
        ),
        if (!_loadingNotifications && _notifications.isNotEmpty)
          _buildListHeader(
            icon: Icons.history_rounded,
            label: 'GÖNDERİLEN BİLDİRİMLER (${_notifications.length})',
            onRefresh: _loadNotifications,
          ),
        Expanded(
          child: _loadingNotifications
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _notifications.isEmpty
                  ? _buildInfoState(
                      Icons.mark_email_read_rounded,
                      'Henüz gönderilmiş bildirim yok.\nYukarıdan yeni bildirim gönderebilirsiniz.',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      color: AppTheme.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _notifications.length,
                        itemBuilder: (_, i) => _buildNotificationCard(_notifications[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildActionHeader({
    required IconData icon,
    required String label,
    required bool isOpen,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isOpen ? accentColor.withValues(alpha: 0.12) : const Color(0xFF0D1526),
            border: Border.all(
              color: isOpen ? accentColor.withValues(alpha: 0.5) : AppTheme.glassBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isOpen ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: isOpen ? Colors.white : accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isOpen ? Colors.white : AppTheme.textSecondary,
                    )),
              ),
              Icon(
                isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: isOpen ? accentColor : AppTheme.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListHeader({
    required IconData icon,
    required String label,
    required VoidCallback onRefresh,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: AppTheme.textMuted, letterSpacing: 0.8)),
          const Spacer(),
          InkWell(
            onTap: onRefresh,
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.refresh_rounded, size: 16, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationComposer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0A1628),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _notificationTitleCtrl,
            decoration: AppTheme.inputDecoration(
                hint: 'Bildirim başlığı *', prefixIcon: Icons.title_rounded),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notificationBodyCtrl,
            minLines: 2, maxLines: 4,
            decoration: AppTheme.inputDecoration(
                hint: 'Bildirim mesajı *', prefixIcon: Icons.message_rounded),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notificationActionCtrl,
            decoration: AppTheme.inputDecoration(
                hint: 'Aksiyon URL (opsiyonel)', prefixIcon: Icons.link_rounded),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _notificationFormOpen = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                    side: const BorderSide(color: AppTheme.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_actionLoading || _loadingNotifications || !_notificationsSupported)
                      ? null : _sendNotification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: _actionLoading
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Gönder', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final title = '${item['title'] ?? '-'}';
    final body = '${item['message'] ?? '-'}';
    final status = '${item['status'] ?? 'created'}';
    final sentAt = '${item['sent_at'] ?? item['created_at'] ?? ''}';
    final isRead = _asBool(item['is_read']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder),
        color: const Color(0xFF0D1526),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              color: Color(0xFF111E36),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isRead ? Icons.drafts_rounded : Icons.notifications_active_rounded,
                    size: 14, color: AppTheme.primaryLight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRead
                        ? AppTheme.textMuted.withValues(alpha: 0.12)
                        : AppTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status == 'read' ? 'Okundu' : 'Gönderildi',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: isRead ? AppTheme.textMuted : AppTheme.primaryLight,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Bildirimi Sil',
                  child: InkWell(
                    onTap: () => _deleteNotification(item),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // İçerik
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(body,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                if (sentAt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 11, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        sentAt.length > 16 ? sentAt.substring(0, 16) : sentAt,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Kampanyalar görünümü ─────────────────────────────────────────────────
  Widget _buildCampaignsView() {
    if (!_loadingCampaigns && !_campaignsSupported) {
      return _buildInfoState(Icons.campaign_rounded, 'Kampanya servisi bu sunucuda aktif değil.');
    }
    return Column(
      children: [
        if (!_campaignFormOpen) _buildTemplateQuickPick(),
        _buildActionHeader(
          icon: Icons.add_circle_outline_rounded,
          label: 'Yeni Kampanya Oluştur',
          isOpen: _campaignFormOpen,
          accentColor: const Color(0xFF7C3AED),
          onTap: () => setState(() => _campaignFormOpen = !_campaignFormOpen),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: _campaignFormOpen ? _buildCampaignComposer() : const SizedBox.shrink(),
        ),
        if (!_loadingCampaigns && _campaigns.isNotEmpty)
          _buildListHeader(
            icon: Icons.view_list_rounded,
            label: 'KAMPANYALAR (${_campaigns.length})',
            onRefresh: _loadCampaigns,
          ),
        Expanded(
          child: _loadingCampaigns
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _campaigns.isEmpty
                  ? _buildInfoState(
                      Icons.campaign_rounded,
                      'Henüz kampanya yok.\nYukarıdan yeni kampanya oluşturabilirsiniz.',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCampaigns,
                      color: AppTheme.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _campaigns.length,
                        itemBuilder: (_, i) => _buildCampaignCard(_campaigns[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTemplateQuickPick() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HIZLI BAŞLAT',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                  color: AppTheme.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kCampaignTemplates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final tpl = _kCampaignTemplates[i];
                final color = Color(tpl['color'] as int);
                return InkWell(
                  onTap: () => _applyTemplate(tpl),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 90),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: color.withValues(alpha: 0.1),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    alignment: Alignment.center,
                    child: Text(tpl['label'] as String,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignComposer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0A1628),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Mini şablon seçici
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kCampaignTemplates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final tpl = _kCampaignTemplates[i];
                final color = Color(tpl['color'] as int);
                return InkWell(
                  onTap: () => _applyTemplate(tpl),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: color.withValues(alpha: 0.1),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(tpl['label'] as String,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          _formLabel('BAŞLIK VE AÇIKLAMA'),
          const SizedBox(height: 8),
          TextField(
            controller: _campaignTitleCtrl,
            decoration: AppTheme.inputDecoration(
                hint: 'Kampanya başlığı *', prefixIcon: Icons.campaign_rounded),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _campaignDescriptionCtrl,
            minLines: 2, maxLines: 3,
            decoration: AppTheme.inputDecoration(
                hint: 'Kısa açıklama *', prefixIcon: Icons.description_rounded),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _campaignDetailsCtrl,
            minLines: 1, maxLines: 2,
            decoration: AppTheme.inputDecoration(
                hint: 'Detay / alt not (opsiyonel)', prefixIcon: Icons.notes_rounded),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _selectedServiceId,
            isExpanded: true,
            decoration: AppTheme.inputDecoration(
              hint: _loadingServices ? 'Servisler yükleniyor...' : 'Servis seçin *',
              prefixIcon: Icons.design_services_rounded,
            ),
            items: _services.map((item) {
              final id = _readServiceId(item);
              return DropdownMenuItem<int>(
                value: id,
                child: Text(_readServiceName(item), maxLines: 1, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: _loadingServices
                ? null
                : (v) {
                    final found = _services.firstWhere(
                        (e) => _readServiceId(e) == v, orElse: () => {});
                    setState(() {
                      _selectedServiceId = v;
                      _selectedServiceName = found.isEmpty ? '' : _readServiceName(found);
                    });
                  },
          ),

          const SizedBox(height: 14),
          _formLabel('GÖRSEL'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _campaignCoverImageCtrl,
                  decoration: AppTheme.inputDecoration(
                      hint: 'Kapak görsel URL', prefixIcon: Icons.image_rounded),
                ),
              ),
              const SizedBox(width: 10),
              _thumbPreview(_campaignCoverImageCtrl, 46),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _campaignIconCtrl,
                  decoration: AppTheme.inputDecoration(
                      hint: 'Simge URL (opsiyonel)', prefixIcon: Icons.emoji_objects_rounded),
                ),
              ),
              const SizedBox(width: 10),
              _thumbPreview(_campaignIconCtrl, 36),
              const SizedBox(width: 10),
            ],
          ),

          const SizedBox(height: 14),
          _formLabel('AKSİYON BUTONU'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: _campaignCtaLabelCtrl,
                  decoration: AppTheme.inputDecoration(hint: 'Buton metni', prefixIcon: Icons.smart_button_rounded))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _campaignCtaUrlCtrl,
                  decoration: AppTheme.inputDecoration(hint: 'Hedef URL', prefixIcon: Icons.link_rounded))),
            ],
          ),

          const SizedBox(height: 14),
          _formLabel('YAYIM DURUMU'),
          const SizedBox(height: 8),
          Row(
            children: [
              _statusToggleBtn(
                  label: 'Aktif', icon: Icons.check_circle_rounded,
                  selected: _campaignActive, color: AppTheme.success,
                  onTap: () => setState(() => _campaignActive = true)),
              const SizedBox(width: 8),
              _statusToggleBtn(
                  label: 'Pasif', icon: Icons.pause_circle_rounded,
                  selected: !_campaignActive, color: AppTheme.error,
                  onTap: () => setState(() => _campaignActive = false)),
            ],
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _campaignFormOpen = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                    side: const BorderSide(color: AppTheme.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_actionLoading || _loadingCampaigns || !_campaignsSupported)
                      ? null : _saveCampaign,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: _actionLoading
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          // Column.children kapanışı
          ],
        ),
      ),
    );
  }

  Widget _formLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3, height: 12,
          margin: const EdgeInsets.only(right: 7),
          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2)),
        ),
        Text(label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                color: AppTheme.textMuted, letterSpacing: 0.8)),
      ],
    );
  }

  Widget _statusToggleBtn({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(color: selected ? color.withValues(alpha: 0.5) : AppTheme.glassBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? color : AppTheme.textMuted),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: selected ? color : AppTheme.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPreview(TextEditingController ctrl, double size) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: ctrl,
      builder: (_, val, __) {
        final url = val.text.trim();
        if (url.isEmpty) return SizedBox(width: size, height: size);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.2),
          child: Image.network(url, width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: size, height: size,
                decoration: BoxDecoration(
                  color: AppTheme.glassBorder,
                  borderRadius: BorderRadius.circular(size * 0.2),
                ),
                child: Icon(Icons.broken_image_rounded,
                    size: size * 0.4, color: AppTheme.textMuted),
              )),
        );
      },
    );
  }

  // ─── Kampanya kartı ───────────────────────────────────────────────────────
  Widget _buildCampaignCard(Map<String, dynamic> item) {
    final title = '${item['title'] ?? '-'}';
    final description = '${item['description'] ?? ''}';
    final details = '${item['details'] ?? ''}';
    final ctaLabel = '${item['cta_label'] ?? ''}';
    final ctaUrl = '${item['cta_url'] ?? item['link_url'] ?? ''}';
    final active = _asBool(item['is_active'] ?? item['active']);
    final coverImage = '${item['cover_image'] ?? item['media_url'] ?? item['image'] ?? ''}'.trim();
    final icon = '${item['icon'] ?? item['icon_url'] ?? ''}'.trim();
    final serviceName = '${item['service_name'] ?? item['service'] ?? ''}'.trim();
    final range = _campaignRange(item);
    final statusColor = active ? AppTheme.success : AppTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder),
        color: const Color(0xFF0D1526),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coverImage.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: AspectRatio(
                aspectRatio: 16 / 6,
                child: Image.network(coverImage, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF0D1526),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_rounded, color: AppTheme.textMuted),
                    )),
              ),
            ),

          // Başlık alanı
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: coverImage.isNotEmpty
                  ? BorderRadius.zero
                  : const BorderRadius.vertical(top: Radius.circular(13)),
              color: const Color(0xFF111E36),
            ),
            child: Row(
              children: [
                Container(
                  width: 3, height: 34,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                      color: statusColor, borderRadius: BorderRadius.circular(2)),
                ),
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: AppTheme.primary.withValues(alpha: 0.15),
                  ),
                  child: icon.startsWith('http')
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(icon, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.campaign_rounded, color: AppTheme.primaryLight, size: 15)),
                        )
                      : const Icon(Icons.campaign_rounded, color: AppTheme.primaryLight, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: active ? Colors.white : AppTheme.textMuted,
                            decoration: active ? null : TextDecoration.lineThrough,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (serviceName.isNotEmpty)
                        Text(serviceName,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(active ? 'Aktif' : 'Pasif',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                ),
                const SizedBox(width: 2),
                Tooltip(
                  message: active ? 'Pasife Al' : 'Aktife Al',
                  child: InkWell(
                    onTap: () => _toggleCampaignActive(item, !active),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                          active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                          size: 26, color: statusColor),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Kampanyayı Sil',
                  child: InkWell(
                    onTap: () => _deleteCampaign(item),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppTheme.error),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // İçerik
          if (description.isNotEmpty || details.isNotEmpty || range.isNotEmpty || ctaLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description.isNotEmpty)
                    Text(description,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(details,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  if (range.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.date_range_rounded, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(range, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ],
                  if (ctaLabel.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [AppTheme.primary, AppTheme.primaryLight]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(ctaLabel,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                        if (ctaUrl.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(ctaUrl,
                                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoState(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.6)),
          ],
        ),
      ),
    );
  }
}
