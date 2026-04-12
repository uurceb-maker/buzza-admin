import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/kategori.dart';
import '../models/servis.dart';
import 'servis_row.dart';

class KategoriTile extends StatelessWidget {
  final Kategori kategori;
  final List<Servis> filtrelenmisServisler;
  final bool gorunur;
  final VoidCallback onToggleVisibility;
  final VoidCallback onEdit;

  const KategoriTile({
    super.key,
    required this.kategori,
    required this.filtrelenmisServisler,
    required this.gorunur,
    required this.onToggleVisibility,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.catalogColors;
    final titleColor = gorunur ? Colors.white : AppTheme.textMuted;
    final borderColor = gorunur
        ? AppTheme.glassBorder
        : colors.passiveRed.withValues(alpha: 0.3);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          expansionAnimationStyle: const AnimationStyle(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          leading: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.accentBlue.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${kategori.siraNo}',
              style: TextStyle(
                color: colors.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            kategori.ad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              decoration: gorunur ? null : TextDecoration.lineThrough,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${kategori.servisSayisi} servis · ${kategori.pasifSayisi} pasif',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: onToggleVisibility,
                tooltip: gorunur ? 'Gizle' : 'Goster',
                icon: Icon(
                  gorunur
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: gorunur ? colors.activeGreen : colors.passiveRed,
                  size: 20,
                ),
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: 'Duzenle',
                icon: const Icon(
                  Icons.edit_rounded,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
          children: [
            if (filtrelenmisServisler.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Gosterilecek servis bulunamadi.',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtrelenmisServisler.length,
                itemBuilder: (context, index) => ServisRow(
                  servis: filtrelenmisServisler[index],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
