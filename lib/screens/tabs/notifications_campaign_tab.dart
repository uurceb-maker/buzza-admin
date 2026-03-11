import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/admin_api.dart';

class NotificationsCampaignTab extends StatefulWidget {
  const NotificationsCampaignTab({super.key});

  @override
  State<NotificationsCampaignTab> createState() =>
      _NotificationsCampaignTabState();
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
    await Future.wait([
      _loadNotifications(),
      _loadCampaigns(),
      _loadServices(),
    ]);
  }

  Future<void> _loadNotifications() async {
    setState(() => _loadingNotifications = true);
    try {
      final data = await AdminApi().getNotifications(page: 1);
      final rawItems = (data['items'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _notifications = rawItems
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _notificationsSupported = data['supported'] != false;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e', AppTheme.error);
    } finally {
      if (mounted) {
        setState(() => _loadingNotifications = false);
      }
    }
  }

  Future<void> _loadCampaigns() async {
    setState(() => _loadingCampaigns = true);
    try {
      final data = await AdminApi().getCampaigns(page: 1);
      final rawItems = (data['items'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _campaigns = rawItems
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _campaignsSupported = data['supported'] != false;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e', AppTheme.error);
    } finally {
      if (mounted) {
        setState(() => _loadingCampaigns = false);
      }
    }
  }

  Future<void> _loadServices() async {
    setState(() => _loadingServices = true);
    try {
      final data = await AdminApi().getServices(page: 1, active: '1');
      final rawItems = (data['items'] as List?) ?? const [];
      final serviceItems = rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => _readServiceId(item) > 0)
          .toList();
      if (!mounted) return;
      setState(() {
        _services = serviceItems;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Servis listesi alınamadı: $e', AppTheme.warning);
    } finally {
      if (mounted) {
        setState(() => _loadingServices = false);
      }
    }
  }

  Future<void> _sendNotification() async {
    final title = _notificationTitleCtrl.text.trim();
    final body = _notificationBodyCtrl.text.trim();
    final actionUrl = _notificationActionCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _showSnack('Bildirim başlığı ve mesaj zorunludur.', AppTheme.warning);
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
      _showSnack('Bildirim gönderildi.', AppTheme.success);
      await _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e', AppTheme.error);
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _saveCampaign() async {
    final title = _campaignTitleCtrl.text.trim();
    final description = _campaignDescriptionCtrl.text.trim();
    final details = _campaignDetailsCtrl.text.trim();
    final ctaLabel = _campaignCtaLabelCtrl.text.trim();
    final ctaUrl = _campaignCtaUrlCtrl.text.trim();
    final coverImage = _campaignCoverImageCtrl.text.trim();
    final icon = _campaignIconCtrl.text.trim();

    if (title.isEmpty || description.isEmpty) {
      _showSnack('Kampanya başlığı ve açıklaması zorunludur.', AppTheme.warning);
      return;
    }

    if ((_selectedServiceId ?? 0) <= 0) {
      _showSnack('Kampanya için servis seçmelisiniz.', AppTheme.warning);
      return;
    }

    setState(() => _actionLoading = true);
    try {
      await AdminApi().createCampaign({
        'title': title,
        'description': description,
        'details': details,
        'cta_label': ctaLabel,
        'cta_url': ctaUrl,
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
      _selectedServiceId = null;
      _selectedServiceName = '';
      _showSnack('Kampanya kaydedildi.', AppTheme.success);
      await _loadCampaigns();
    } catch (e) {
      if (!mounted) return;
      _showSnack('$e', AppTheme.error);
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '$value'.trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'on' ||
        text == 'active';
  }

  int _readServiceId(Map<String, dynamic> item) {
    final raw = item['id'] ?? item['service_id'] ?? item['provider_service_id'];
    return int.tryParse('$raw') ?? 0;
  }

  String _readServiceName(Map<String, dynamic> item) {
    final name = '${item['name'] ?? item['service_name'] ?? item['title'] ?? ''}'
        .trim();
    if (name.isNotEmpty) return name;
    final id = _readServiceId(item);
    return id > 0 ? 'Servis #$id' : '-';
  }

  bool _isInvalidDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return true;
    return text.startsWith('0000-00-00');
  }

  String _campaignRange(Map<String, dynamic> item) {
    final startRaw = '${item['start_at'] ?? item['start_date'] ?? ''}';
    final endRaw = '${item['end_at'] ?? item['end_date'] ?? ''}';
    final start = _isInvalidDate(startRaw) ? '' : startRaw.trim();
    final end = _isInvalidDate(endRaw) ? '' : endRaw.trim();
    if (start.isEmpty && end.isEmpty) return '';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Bildirimler'),
              Tab(text: 'Kampanyalar'),
            ],
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primaryLight,
            unselectedLabelColor: AppTheme.textMuted,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildNotificationsView(),
              _buildCampaignsView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsView() {
    return Column(
      children: [
        _buildNotificationComposer(),
        const SizedBox(height: 8),
        Expanded(
          child: _loadingNotifications
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : !_notificationsSupported
                  ? _buildInfoState('Bildirim servisi bu sunucuda aktif değil.')
                  : _notifications.isEmpty
                      ? _buildInfoState('Henüz bildirim yok.')
                      : RefreshIndicator(
                          onRefresh: _loadNotifications,
                          color: AppTheme.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) =>
                                _buildNotificationCard(_notifications[index]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildCampaignsView() {
    return Column(
      children: [
        _buildCampaignComposer(),
        const SizedBox(height: 8),
        Expanded(
          child: _loadingCampaigns
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : !_campaignsSupported
                  ? _buildInfoState('Kampanya servisi bu sunucuda aktif değil.')
                  : _campaigns.isEmpty
                      ? _buildInfoState('Henüz kampanya yok.')
                      : RefreshIndicator(
                          onRefresh: _loadCampaigns,
                          color: AppTheme.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _campaigns.length,
                            itemBuilder: (context, index) =>
                                _buildCampaignCard(_campaigns[index]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildNotificationComposer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassDecoration(radius: 14),
      child: Column(
        children: [
          TextField(
            controller: _notificationTitleCtrl,
            decoration: AppTheme.inputDecoration(
              hint: 'Bildirim başlığı',
              prefixIcon: Icons.title,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notificationBodyCtrl,
            minLines: 2,
            maxLines: 3,
            decoration: AppTheme.inputDecoration(
              hint: 'Bildirim mesajı',
              prefixIcon: Icons.message_rounded,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notificationActionCtrl,
            decoration: AppTheme.inputDecoration(
              hint: 'Aksiyon URL (opsiyonel)',
              prefixIcon: Icons.link_rounded,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _actionLoading ? null : _sendNotification,
              icon: _actionLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Bildirim Gönder'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignComposer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassDecoration(radius: 14),
      child: Column(
        children: [
          TextField(
            controller: _campaignTitleCtrl,
            decoration: AppTheme.inputDecoration(
              hint: 'Kampanya başlığı',
              prefixIcon: Icons.campaign_rounded,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _campaignDescriptionCtrl,
            minLines: 2,
            maxLines: 3,
            decoration: AppTheme.inputDecoration(
              hint: 'Kampanya açıklaması',
              prefixIcon: Icons.description_rounded,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _campaignDetailsCtrl,
            minLines: 1,
            maxLines: 3,
            decoration: AppTheme.inputDecoration(
              hint: 'Detay (opsiyonel)',
              prefixIcon: Icons.notes_rounded,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _selectedServiceId,
            isExpanded: true,
            decoration: AppTheme.inputDecoration(
              hint: _loadingServices ? 'Servisler yükleniyor...' : 'Servis seçin',
              prefixIcon: Icons.design_services_rounded,
            ),
            items: _services
                .map((item) {
                  final id = _readServiceId(item);
                  final name = _readServiceName(item);
                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                })
                .toList(),
            onChanged: _loadingServices
                ? null
                : (value) {
                    final found = _services.firstWhere(
                      (item) => _readServiceId(item) == value,
                      orElse: () => <String, dynamic>{},
                    );
                    setState(() {
                      _selectedServiceId = value;
                      _selectedServiceName =
                          found.isEmpty ? '' : _readServiceName(found);
                    });
                  },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _campaignCoverImageCtrl,
                  decoration: AppTheme.inputDecoration(
                    hint: 'Kapak görsel URL',
                    prefixIcon: Icons.image_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _campaignIconCtrl,
                  decoration: AppTheme.inputDecoration(
                    hint: 'Simge URL',
                    prefixIcon: Icons.emoji_objects_rounded,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _campaignCtaLabelCtrl,
                  decoration: AppTheme.inputDecoration(
                    hint: 'Buton metni',
                    prefixIcon: Icons.smart_button_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _campaignCtaUrlCtrl,
                  decoration: AppTheme.inputDecoration(
                    hint: 'CTA URL',
                    prefixIcon: Icons.link_rounded,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Durum',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Aktif'),
                selected: _campaignActive,
                onSelected: (_) => setState(() => _campaignActive = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Pasif'),
                selected: !_campaignActive,
                onSelected: (_) => setState(() => _campaignActive = false),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCampaignPreview(),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _actionLoading ? null : _saveCampaign,
              icon: _actionLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: const Text('Kampanya Kaydet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignPreview() {
    final title = _campaignTitleCtrl.text.trim().isEmpty
        ? 'Kampanya başlığı'
        : _campaignTitleCtrl.text.trim();
    final description = _campaignDescriptionCtrl.text.trim().isEmpty
        ? 'Kampanya açıklaması'
        : _campaignDescriptionCtrl.text.trim();
    final coverImage = _campaignCoverImageCtrl.text.trim();
    final icon = _campaignIconCtrl.text.trim();
    final cta = _campaignCtaLabelCtrl.text.trim();
    final service = _selectedServiceName.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.glassDecoration(
        radius: 14,
        borderColor: AppTheme.primary.withValues(alpha: 0.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coverImage.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 6,
                child: Image.network(
                  coverImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0x22111A3A),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppTheme.primary.withValues(alpha: 0.18),
                ),
                child: icon.startsWith('http')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(
                          icon,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.campaign_rounded,
                            color: AppTheme.primaryLight,
                            size: 18,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.campaign_rounded,
                        color: AppTheme.primaryLight,
                        size: 18,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (_campaignActive ? AppTheme.success : AppTheme.error)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _campaignActive ? 'Aktif' : 'Pasif',
                  style: TextStyle(
                    fontSize: 10,
                    color: _campaignActive ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
          if (service.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                service,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (cta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                cta,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final title = '${item['title'] ?? '-'}';
    final body = '${item['message'] ?? '-'}';
    final status = '${item['status'] ?? 'created'}';
    final sentAt = '${item['sent_at'] ?? item['created_at'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: const TextStyle(fontSize: 10, color: AppTheme.primaryLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          if (sentAt.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(sentAt, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> item) {
    final title = '${item['title'] ?? '-'}';
    final description = '${item['description'] ?? ''}';
    final details = '${item['details'] ?? ''}';
    final ctaLabel = '${item['cta_label'] ?? ''}';
    final ctaUrl = '${item['cta_url'] ?? item['link_url'] ?? ''}';
    final active = _asBool(item['is_active'] ?? item['active']);
    final coverImage =
        '${item['cover_image'] ?? item['media_url'] ?? item['image'] ?? ''}'.trim();
    final icon = '${item['icon'] ?? item['icon_url'] ?? ''}'.trim();
    final serviceName =
        '${item['service_name'] ?? item['service'] ?? ''}'.trim();
    final range = _campaignRange(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassDecoration(
        radius: 14,
        borderColor:
            active ? AppTheme.glassBorder : AppTheme.error.withValues(alpha: 0.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coverImage.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Image.network(
                  coverImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0x22111A3A),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppTheme.primary.withValues(alpha: 0.18),
                ),
                child: icon.startsWith('http')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(
                          icon,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.campaign_rounded,
                            color: AppTheme.primaryLight,
                            size: 18,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.campaign_rounded,
                        color: AppTheme.primaryLight,
                        size: 18,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: active ? null : TextDecoration.lineThrough,
                    color: active ? Colors.white : AppTheme.textMuted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (active ? AppTheme.success : AppTheme.error)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  active ? 'Aktif' : 'Pasif',
                  style: TextStyle(
                    fontSize: 10,
                    color: active ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
          if (serviceName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                serviceName,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(details, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
          if (range.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(range, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
          if (ctaLabel.isNotEmpty || ctaUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (ctaLabel.isNotEmpty)
                  Text(ctaLabel, style: const TextStyle(fontSize: 11, color: AppTheme.primaryLight)),
                if (ctaUrl.isNotEmpty) ...[
                  if (ctaLabel.isNotEmpty) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ctaUrl,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textMuted),
        ),
      ),
    );
  }
}
