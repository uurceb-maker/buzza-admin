import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/servis.dart';

enum ServisRowVariant { compact, card }

class ServisRow extends StatelessWidget {
  final Servis servis;
  final ServisRowVariant variant;

  const ServisRow({
    super.key,
    required this.servis,
    this.variant = ServisRowVariant.compact,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.catalogColors;
    final statusColor = servis.aktif ? colors.activeGreen : colors.passiveRed;

    if (variant == ServisRowVariant.card) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IdChip(id: servis.id),
                const Spacer(),
                _StatusBadge(
                  label: servis.aktif ? 'Aktif' : 'Pasif',
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              servis.ad,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(label: 'Min ${servis.min}'),
                      _InfoPill(label: 'Max ${servis.max}'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatPrice(servis.fiyat),
                  style: TextStyle(
                    color: colors.accentBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.32),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _IdChip(id: servis.id),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              servis.ad,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: servis.aktif ? Colors.white : AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatPrice(servis.fiyat),
            style: TextStyle(
              color: colors.accentBlue,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double value) =>
      '₺${value.toStringAsFixed(2).replaceAll('.', ',')}';
}

class _IdChip extends StatelessWidget {
  final int id;

  const _IdChip({required this.id});

  @override
  Widget build(BuildContext context) {
    final colors = context.catalogColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.accentBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.accentBlue.withValues(alpha: 0.22)),
      ),
      child: Text(
        '#$id',
        style: TextStyle(
          color: colors.accentBlue,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;

  const _InfoPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.glassBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
