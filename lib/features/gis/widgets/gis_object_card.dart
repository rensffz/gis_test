// lib/features/gis/widgets/gis_object_card.dart
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../models/app_models.dart';

class GisObjectCard extends StatelessWidget {
  final GisObject object;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const GisObjectCard({super.key, required this.object, required this.onTap, required this.onEdit, required this.onDelete});

  String _fmt(DateTime dt) {
    const m = ['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'];
    return '${dt.day} ${m[dt.month-1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tp = isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final ts = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.accent.withOpacity(0.06),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0,2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(object.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tp, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: object.category.color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                      child: Text(object.category.name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: object.category.color))),
                  ])),
                ]),
                const SizedBox(height: 8),
                Text(object.description, style: TextStyle(fontSize: 12, color: ts, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Row(children: [
                  _Chip(icon: Icons.layers_outlined, label: '${object.layerCount} слоёв', color: AppColors.layerPolygon, isDark: isDark),
                  const Spacer(),
                  Icon(Icons.history_rounded, size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(_fmt(object.updatedAt), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  _ActBtn(Icons.edit_outlined, onEdit),
                  const SizedBox(width: 3),
                  _ActBtn(Icons.delete_outline_rounded, onDelete, color: AppColors.error),
                  const SizedBox(width: 3),
                  _ActBtn(Icons.chevron_right_rounded, onTap),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color color;
  const _ActBtn(this.icon, this.onTap, {this.color = AppColors.textMuted});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(5),
    child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 15, color: color)));
}

class _Chip extends StatelessWidget {
  final IconData icon; final String label; final Color color; final bool isDark;
  const _Chip({required this.icon, required this.label, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: isDark ? AppColors.surfaceDark : AppColors.bgLight,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color), const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)),
    ]),
  );
}
