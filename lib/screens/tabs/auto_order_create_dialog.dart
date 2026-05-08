import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../models/auto_order.dart';
import '../../services/admin_api.dart';

class AutoOrderCreateDialog extends StatefulWidget {
  const AutoOrderCreateDialog({super.key});

  @override
  State<AutoOrderCreateDialog> createState() =>
      _AutoOrderCreateDialogState();
}

class _AutoOrderCreateDialogState extends State<AutoOrderCreateDialog> {
  final _api = AdminApi();
  final _formKey = GlobalKey<FormState>();
  final _userIdCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _totalQtyCtrl = TextEditingController();
  final _perRunQtyCtrl = TextEditingController();

  bool _loading = true;
  bool _submitting = false;

  List<AutoOrderService> _services = const [];
  List<AutoOrderInterval> _intervals = const [];
  AutoOrderService? _service;
  AutoOrderInterval? _interval;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _linkCtrl.dispose();
    _totalQtyCtrl.dispose();
    _perRunQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final results = await Future.wait([
        _api.getAutoOrderServices(),
        _api.getAutoOrderIntervals(),
      ]);
      if (!mounted) return;
      final svcMap = results[0];
      final intMap = results[1];
      setState(() {
        _services = ((svcMap['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AutoOrderService.fromJson(
                Map<String, dynamic>.from(e)))
            .toList();
        _intervals = ((intMap['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => AutoOrderInterval.fromJson(
                Map<String, dynamic>.from(e)))
            .toList();
        if (_intervals.isNotEmpty) {
          _interval = _intervals.firstWhere(
              (i) => i.seconds >= 3600,
              orElse: () => _intervals.first);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hata: $e'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_service == null || _interval == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      await _api.createAutoOrder(
        userId: int.parse(_userIdCtrl.text),
        serviceId: _service!.id,
        targetLink: _linkCtrl.text.trim(),
        totalQuantity: int.parse(_totalQtyCtrl.text),
        perRunQuantity: int.parse(_perRunQtyCtrl.text),
        runInterval: _interval!.seconds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Otomatik sipariş oluşturuldu'),
        backgroundColor: AppTheme.success,
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$e'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgCard,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primary))
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.primary
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.flash_on_rounded,
                                color: AppTheme.primary, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Yeni Otomatik Sipariş',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            AppTheme.textPrimary)),
                                Text('Müşteri için manuel oluştur',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _submitting
                                ? null
                                : () => Navigator.pop(context, false),
                            icon: const Icon(Icons.close_rounded,
                                color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _label('Kullanıcı ID'),
                              TextFormField(
                                controller: _userIdCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                decoration: AppTheme.inputDecoration(
                                  hint: 'Örn: 42',
                                  prefixIcon: Icons.person_outline,
                                ),
                                validator: (v) {
                                  final n = int.tryParse(v ?? '') ?? 0;
                                  return n < 1
                                      ? 'Geçerli kullanıcı ID girin'
                                      : null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _label('Servis'),
                              DropdownButtonFormField<AutoOrderService>(
                                value: _service,
                                isExpanded: true,
                                dropdownColor: AppTheme.bgCard,
                                decoration: AppTheme.inputDecoration(
                                  hint: _services.isEmpty
                                      ? 'Açık servis yok'
                                      : 'Servis seçin',
                                  prefixIcon: Icons.design_services_rounded,
                                ),
                                items: _services
                                    .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(
                                            '${s.name}  •  ₺${s.ratePer1k.toStringAsFixed(2)}/1k',
                                            style: const TextStyle(
                                                fontSize: 13),
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                validator: (v) =>
                                    v == null ? 'Servis seçin' : null,
                                onChanged: (v) {
                                  setState(() {
                                    _service = v;
                                    if (v != null &&
                                        _perRunQtyCtrl.text.isEmpty) {
                                      _perRunQtyCtrl.text =
                                          '${v.autoOrderMinPerRun}';
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              _label('Hedef Link'),
                              TextFormField(
                                controller: _linkCtrl,
                                keyboardType: TextInputType.url,
                                decoration: AppTheme.inputDecoration(
                                  hint: 'https://...',
                                  prefixIcon: Icons.link_rounded,
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Link gerekli'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _label('Toplam Miktar'),
                                        TextFormField(
                                          controller: _totalQtyCtrl,
                                          keyboardType:
                                              TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly
                                          ],
                                          decoration:
                                              AppTheme.inputDecoration(
                                                  hint: '10000'),
                                          validator: (v) {
                                            final n =
                                                int.tryParse(v ?? '') ??
                                                    0;
                                            return n < 1
                                                ? 'Gerekli'
                                                : null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _label('Parti Miktarı'),
                                        TextFormField(
                                          controller: _perRunQtyCtrl,
                                          keyboardType:
                                              TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly
                                          ],
                                          decoration:
                                              AppTheme.inputDecoration(
                                                  hint: _service != null
                                                      ? '${_service!.autoOrderMinPerRun}'
                                                      : '1000'),
                                          validator: (v) {
                                            final n =
                                                int.tryParse(v ?? '') ??
                                                    0;
                                            if (n < 1) return 'Gerekli';
                                            if (_service != null) {
                                              if (n <
                                                  _service!
                                                      .autoOrderMinPerRun) {
                                                return 'Min ${_service!.autoOrderMinPerRun}';
                                              }
                                              if (n >
                                                  _service!
                                                      .autoOrderMaxPerRun) {
                                                return 'Max ${_service!.autoOrderMaxPerRun}';
                                              }
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _label('Tekrar Aralığı'),
                              DropdownButtonFormField<AutoOrderInterval>(
                                value: _interval,
                                isExpanded: true,
                                dropdownColor: AppTheme.bgCard,
                                decoration: AppTheme.inputDecoration(
                                  hint: 'Aralık',
                                  prefixIcon: Icons.timer_outlined,
                                ),
                                items: _intervals
                                    .map((i) => DropdownMenuItem(
                                          value: i,
                                          child: Text(i.label,
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ))
                                    .toList(),
                                validator: (v) =>
                                    v == null ? 'Aralık seçin' : null,
                                onChanged: (v) =>
                                    setState(() => _interval = v),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme.warning
                                          .withValues(alpha: 0.25)),
                                ),
                                child: const Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline_rounded,
                                        size: 14,
                                        color: AppTheme.warning),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Toplam tutar oluşturulurken kullanıcının bakiyesinden rezerve edilir.',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                AppTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _submitting
                                  ? null
                                  : () =>
                                      Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                foregroundColor:
                                    AppTheme.textSecondary,
                                side: const BorderSide(
                                    color: AppTheme.glassBorder),
                              ),
                              child: const Text('Vazgeç'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _submitting ? null : _submit,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white))
                                  : const Icon(Icons.flash_on_rounded,
                                      size: 16),
                              label: Text(_submitting
                                  ? 'Oluşturuluyor...'
                                  : 'Oluştur'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 2),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: AppTheme.textMuted),
      ),
    );
  }
}
