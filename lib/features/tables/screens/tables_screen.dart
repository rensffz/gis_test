// lib/features/tables/screens/tables_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../models/app_models.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/common_widgets.dart';

class TablesScreen extends ConsumerStatefulWidget {
  final bool embedded; // true = встроена в ObjectsScreen как вкладка
  const TablesScreen({super.key, this.embedded = false});
  @override
  ConsumerState<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends ConsumerState<TablesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _openEditor({AttributeTable? t}) {
    if (t == null) { context.go(AppRoutes.tableNew); return; }
    context.go('${AppRoutes.tables}/${t.id}/edit', extra: t);
  }

  Future<void> _delete(AttributeTable t) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      title: const Text('Удалить таблицу?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      content: Text('«${t.name}» и все ${t.propertyCount} свойств будут удалены.',
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: AppColors.textSecondary))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
          child: const Text('Удалить')),
      ],
    ));
    if (ok == true && mounted) {
      await ref.read(tablesProvider.notifier).delete(t.id);
      if (mounted) showAppSnackbar(context, '«${t.name}» удалена', icon: Icons.delete_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(filteredTablesProvider);

    Widget body = Column(
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) { ref.read(tableSearchProvider.notifier).state = v; setState(() {}); },
            decoration: InputDecoration(
              hintText: 'Поиск таблиц...',
              suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close_rounded, size: 17, color: AppColors.textMuted),
                    onPressed: () { _searchCtrl.clear(); ref.read(tableSearchProvider.notifier).state = ''; setState(() {}); })
                : null,
              fillColor: isDark ? AppColors.cardDark : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Divider(height: 1, color: isDark ? AppColors.dividerDark : AppColors.borderLight),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(tablesProvider.notifier).reload(),
            color: AppColors.accent,
            child: async.when(
              loading: () => _Skeleton(),
              error: (e, _) => AppEmptyState(icon: Icons.error_outline_rounded, title: 'Ошибка', subtitle: e.toString()),
              data: (tables) {
                if (tables.isEmpty) return AppEmptyState(icon: Icons.table_rows_outlined,
                  title: _searchCtrl.text.isNotEmpty ? 'Не найдено' : 'Нет таблиц', subtitle: 'Нажмите + для создания');
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  itemCount: tables.length,
                  itemBuilder: (_, i) => _TableCard(
                    table: tables[i], index: i, isDark: isDark,
                    onOpen: () => context.go('${AppRoutes.tables}/${tables[i].id}', extra: tables[i]),
                    onEdit: () => _openEditor(t: tables[i]),
                    onDelete: () => _delete(tables[i]),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Stack(children: [
        body,
        Positioned(bottom: 24, right: 20, child: FloatingActionButton.extended(
          heroTag: 'add_tbl', onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded), label: const Text('Новая таблица', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark)),
      ]);
    }

    return Scaffold(
      appBar: GisAppBar(title: 'Таблицы атрибутов', showDrawer: true),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_tbl_main', onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded), label: const Text('Новая таблица', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark),
    );
  }
}

// ── Table card ───────────────────────────────────────────────
class _TableCard extends StatefulWidget {
  final AttributeTable table;
  final int index;
  final bool isDark;
  final VoidCallback onOpen, onEdit, onDelete;
  const _TableCard({required this.table, required this.index, required this.isDark, required this.onOpen, required this.onEdit, required this.onDelete});

  @override State<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<_TableCard> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _f;
  late Animation<Offset> _s;
  bool _hov = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: 280 + widget.index * 50));
    _f = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _s = Tween(begin: const Offset(0, 0.07), end: Offset.zero).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index * 50), () { if (mounted) _c.forward(); });
  }

  @override void dispose() { _c.dispose(); super.dispose(); }

  String _fmt(DateTime dt) { const m = ['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек']; return '${dt.day} ${m[dt.month-1]} ${dt.year}'; }

  @override
  Widget build(BuildContext context) {
    final tp = widget.isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;
    final ts = widget.isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final bd = widget.isDark ? AppColors.borderDark : AppColors.borderLight;
    final bg = widget.isDark ? AppColors.cardDark : Colors.white;

    return FadeTransition(opacity: _f, child: SlideTransition(position: _s,
      child: Padding(padding: const EdgeInsets.only(bottom: 10),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hov = true),
          onExit: (_) => setState(() => _hov = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _hov ? AppColors.accent.withOpacity(0.35) : bd, width: _hov ? 1.5 : 1),
              boxShadow: _hov ? [BoxShadow(color: AppColors.accent.withOpacity(0.07), blurRadius: 14, offset: const Offset(0,4))]
                  : widget.isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 5, offset: const Offset(0,2))]),
            child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(16),
              child: InkWell(onTap: widget.onOpen, borderRadius: BorderRadius.circular(16),
                splashColor: AppColors.accent.withOpacity(0.05),
                child: Padding(padding: const EdgeInsets.all(15), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: AppColors.accent.withOpacity(0.2))),
                        child: const Icon(Icons.table_rows_rounded, color: AppColors.accent, size: 19)),
                      const SizedBox(width: 11),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.table.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tp, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(widget.table.description, style: TextStyle(fontSize: 11, color: ts, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ])),
                    ]),
                    const SizedBox(height: 10),
                    Divider(height: 1, color: widget.isDark ? AppColors.dividerDark : AppColors.borderLight),
                    const SizedBox(height: 8),
                    Row(children: [
                      _Chip2(Icons.tune_rounded, '${widget.table.propertyCount} свойств', AppColors.layerPolygon, widget.isDark),
                      const Spacer(),
                      Icon(Icons.history_rounded, size: 12, color: AppColors.textMuted), const SizedBox(width: 3),
                      Text(_fmt(widget.table.updatedAt), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      const SizedBox(width: 10),
                      _SmAct(Icons.edit_outlined, widget.onEdit),
                      const SizedBox(width: 3),
                      _SmAct(Icons.delete_outline_rounded, widget.onDelete, color: AppColors.error),
                      const SizedBox(width: 3),
                      _SmAct(Icons.chevron_right_rounded, widget.onOpen),
                    ]),
                  ],
                )),
              ),
            ),
          ),
        ),
      ),
    ));
  }

}

class _Chip2 extends StatelessWidget {
  final IconData i; final String l; final Color c; final bool d;
  const _Chip2(this.i, this.l, this.c, this.d);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: d ? AppColors.surfaceDark : AppColors.bgLight, borderRadius: BorderRadius.circular(7),
      border: Border.all(color: d ? AppColors.borderDark : AppColors.borderLight)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 11, color: c), const SizedBox(width: 4),
      Text(l, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: d ? AppColors.textSecondary : AppColors.textSecondaryLight))]));
}

class _SmAct extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color color;
  const _SmAct(this.icon, this.onTap, {this.color = AppColors.textMuted});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(5),
    child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 15, color: color)));
}

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16), itemCount: 4,
      itemBuilder: (_, __) => Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Container(height: 118,
          decoration: BoxDecoration(color: isDark ? AppColors.cardDark : Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
          child: Padding(padding: const EdgeInsets.all(15), child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [SkeletonBox(width: 40, height: 40, radius: 11), SizedBox(width: 11),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SkeletonBox(height: 14), SizedBox(height: 6), SkeletonBox(height: 11)]))]),
              SizedBox(height: 12), SkeletonBox(height: 1, radius: 0), SizedBox(height: 10),
              Row(children: [SkeletonBox(width: 85, height: 22, radius: 7), Spacer(), SkeletonBox(width: 70, height: 13, radius: 4)]),
            ],
          )),
        )));
  }
}
