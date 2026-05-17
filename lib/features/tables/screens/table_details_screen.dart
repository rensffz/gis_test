// lib/features/tables/screens/table_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
//import '../../../models/app_models.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/common_widgets.dart';

class TableDetailsScreen extends ConsumerWidget {
  final String tableId;
  final String? fromObjectId;
  const TableDetailsScreen({super.key, required this.tableId, this.fromObjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider).valueOrNull ?? [];
    final t = tables.where((x) => x.id == tableId).firstOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    void goBack() => fromObjectId != null
        ? context.go('/objects/$fromObjectId/map')
        : context.go(AppRoutes.tables);

    if (t == null) return Scaffold(appBar: GisAppBar(title: 'Таблица', onBack: goBack),
      body: const AppEmptyState(icon: Icons.table_rows_outlined, title: 'Таблица не найдена'));

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 170,
          pinned: true,
          backgroundColor: AppColors.surfaceDark,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: AppColors.textSecondary), onPressed: goBack),
          actions: [
            IconButton(icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.textSecondary),
              onPressed: () => context.go('${AppRoutes.tables}/${t.id}/edit', extra: t)),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0D1520), AppColors.surfaceDark], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(18, 52, 18, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent.withOpacity(0.3))),
                    child: const Icon(Icons.table_rows_rounded, color: AppColors.accent, size: 20)),
                  const SizedBox(height: 10),
                  Text(t.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                ])))),
          ),
        ),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (t.description.isNotEmpty) ...[
              Text(t.description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
              const SizedBox(height: 12),
              Divider(height: 1, color: AppColors.dividerDark),
              const SizedBox(height: 10),
            ],
            Row(children: [
              _MI(Icons.tune_rounded, 'Свойств', '${t.propertyCount}', AppColors.layerPolygon),
              const SizedBox(width: 18),
              _MI(Icons.history_rounded, 'Обновлено', _fmt(t.updatedAt), AppColors.textSecondary),
            ]),
          ]),
        ))),
        SliverToBoxAdapter(child: SectionHeader(title: 'Свойства',
          action: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(10)),
            child: Text('${t.propertyCount}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent))))),
        t.properties.isEmpty
            ? SliverToBoxAdapter(child: AppEmptyState(icon: Icons.tune_rounded, title: 'Нет свойств',
                action: TextButton.icon(onPressed: () => context.go('${AppRoutes.tables}/${t.id}/edit', extra: t), icon: const Icon(Icons.edit_rounded, size: 15), label: const Text('Редактировать'))))
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) {
                  final p = t.properties[i];
                  return Padding(padding: const EdgeInsets.only(bottom: 7), child: AppCard(
                    padding: const EdgeInsets.all(13),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 24, height: 24, decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Center(child: Text('${i+1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(p.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight))),
                          if (p.measurementUnit.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.accent.withOpacity(0.25))),
                            child: Text(p.measurementUnit, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent, fontFamily: 'monospace'))),
                        ]),
                        if (p.description.isNotEmpty) ...[const SizedBox(height: 3),
                          Text(p.description, style: TextStyle(fontSize: 11, color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis)],
                      ])),
                      const SizedBox(width: 6),
                      InkWell(onTap: () { Clipboard.setData(ClipboardData(text: '${p.name} | ${p.description} | ${p.measurementUnit}')); showAppSnackbar(context, 'Скопировано', icon: Icons.copy_rounded); },
                        borderRadius: BorderRadius.circular(5), child: Padding(padding: const EdgeInsets.all(3), child: const Icon(Icons.copy_outlined, size: 13, color: AppColors.textMuted))),
                    ]),
                  ));
                }, childCount: t.properties.length)),
              ),
      ]),
    );
  }

  static String _fmt(DateTime dt) { const m = ['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек']; return '${dt.day} ${m[dt.month-1]} ${dt.year}'; }
}

class _MI extends StatelessWidget {
  final IconData i; final String l, v; final Color c;
  const _MI(this.i, this.l, this.v, this.c);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(i, size: 13, color: c), const SizedBox(width: 5),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l, style: const TextStyle(fontSize: 9, color: AppColors.textMuted, letterSpacing: 0.3)),
      Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    ]),
  ]);
}
