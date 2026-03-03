import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api.dart';

class CronTab extends StatefulWidget {
  const CronTab({super.key});
  @override
  State<CronTab> createState() => _CronTabState();
}

class _CronTabState extends State<CronTab> {
  List<dynamic> _jobs = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await AdminApi().getCronStatus();
      setState(() { _jobs = d['jobs'] as List? ?? []; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _runJob(String key) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cron çalıştırılıyor...'), backgroundColor: AppTheme.info));
    try {
      final r = await AdminApi().runCronJob(key);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${r['message'] ?? 'Tamamlandı'} (${r['processed'] ?? '-'} işlem)'),
        backgroundColor: AppTheme.success,
      ));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_jobs.isEmpty) return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          const Text('Cron görevi bulunamadı', style: TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 18), label: const Text('Yenile')),
        ],
      ),
    );

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _jobs.length,
        itemBuilder: (ctx, i) => _buildJob(_jobs[i]),
      ),
    );
  }

  Widget _buildJob(dynamic j) {
    final isRunning = j['is_running'] == true;
    final lastRun = j['last_run'] ?? 'Hiç çalışmadı';
    final nextRun = j['next_run'] ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: (isRunning ? AppTheme.success : AppTheme.info).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.schedule, size: 20, color: isRunning ? AppTheme.success : AppTheme.info),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${j['name'] ?? j['key'] ?? '-'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    if (isRunning)
                      const Text('⚡ Çalışıyor', style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w600))
                    else
                      Text('Son: $lastRun', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _runJob('${j['key']}'),
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Çalıştır', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.success,
                  side: BorderSide(color: AppTheme.success.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _infoTag('Sonraki: $nextRun'),
              if (j['interval'] != null) _infoTag('Aralık: ${j['interval']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTag(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppTheme.glassBg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
    );
  }
}
