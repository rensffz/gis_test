// lib/features/gis/screens/objects_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../models/app_models.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../widgets/gis_object_card.dart';
import '../../tables/screens/tables_screen.dart';

class ObjectsScreen extends ConsumerStatefulWidget {
  const ObjectsScreen({super.key});
  @override
  ConsumerState<ObjectsScreen> createState() => _ObjectsScreenState();
}

class _ObjectsScreenState extends ConsumerState<ObjectsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tab.dispose(); _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: GisAppBar(
        title: 'GIS Объекты',
        showDrawer: true,
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, color: isDark ? AppColors.dividerDark : AppColors.borderLight),
            _buildTabBar(isDark),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _ObjectsTab(searchCtrl: _searchCtrl),
          const TablesScreen(embedded: true),
        ],
      ),
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton(
              heroTag: 'add_obj',
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const _CreateObjectDialog(),
              ),
              child: const Icon(Icons.add_rounded))
          : null,
    );
  }

  Widget _buildTabBar(bool isDark) => SizedBox(
    height: 44,
    child: TabBar(
      controller: _tab,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerHeight: 0,
      indicator: BoxDecoration(
        color: AppColors.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      labelColor: AppColors.accent,
      unselectedLabelColor: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      tabs: const [
        Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.place_outlined, size: 15), SizedBox(width: 6), Text('Объекты')])),
        Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.table_rows_outlined, size: 15), SizedBox(width: 6), Text('Таблицы')])),
      ],
    ),
  );
}

class _ObjectsTab extends ConsumerStatefulWidget {
  final TextEditingController searchCtrl;
  const _ObjectsTab({required this.searchCtrl});

  @override
  ConsumerState<_ObjectsTab> createState() => _ObjectsTabState();
}

class _ObjectsTabState extends ConsumerState<_ObjectsTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = ref.watch(filteredObjectsProvider);
    final cats = ref.watch(categoriesProvider);
    final selCat = ref.watch(selectedCategoryProvider);

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: widget.searchCtrl,
            onChanged: (v) { ref.read(objectSearchProvider.notifier).state = v; setState(() {}); },
            decoration: InputDecoration(
              hintText: 'Поиск объектов...',
              suffixIcon: widget.searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                      onPressed: () { widget.searchCtrl.clear(); ref.read(objectSearchProvider.notifier).state = ''; setState(() {}); })
                  : null,
              fillColor: isDark ? AppColors.cardDark : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        // Category chips
        cats.when(
          loading: () => const SizedBox(height: 44),
          error: (_, __) => const SizedBox.shrink(),
          data: (list) => SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: list.map((cat) {
                final sel = selCat == cat.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: sel,
                    label: Text(cat.name),
                    onSelected: (_) => ref.read(selectedCategoryProvider.notifier).state = sel ? null : cat.id,
                    selectedColor: cat.color.withOpacity(0.12),
                    checkmarkColor: cat.color,
                    labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: sel ? cat.color : AppColors.textSecondary),
                    side: BorderSide(color: sel ? cat.color.withOpacity(0.5) : (isDark ? AppColors.borderDark : AppColors.borderLight)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Divider(height: 1, color: isDark ? AppColors.dividerDark : AppColors.borderLight),
        // List
        Expanded(child: RefreshIndicator(
          onRefresh: () async { ref.invalidate(objectsProvider); await ref.read(objectsProvider.future); },
          color: AppColors.accent,
          child: filtered.when(
            loading: () => ListView.builder(itemCount: 4, padding: const EdgeInsets.only(top: 8),
                itemBuilder: (_, __) => _ObjectSkeleton()),
            error: (e, _) => AppEmptyState(icon: Icons.error_outline_rounded, title: 'Ошибка', subtitle: e.toString()),
            data: (objects) {
              if (objects.isEmpty) return AppEmptyState(icon: Icons.search_off_rounded, title: 'Ничего не найдено');
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: objects.length,
                itemBuilder: (_, i) => GisObjectCard(
                  object: objects[i],
                  onTap: () => context.go('/objects/${objects[i].id}/map', extra: objects[i]),
                  onEdit: () => showAppSnackbar(context, 'Редактирование объекта будет реализовано', icon: Icons.info_outline_rounded),
                  onDelete: () => showAppSnackbar(context, 'Удаление объекта будет реализовано', icon: Icons.info_outline_rounded),
                ),
              );
            },
          ),
        )),
      ],
    );
  }
}

// ─── Create GIS Object dialog ─────────────────────────────────
class _CreateObjectDialog extends ConsumerStatefulWidget {
  const _CreateObjectDialog();
  @override
  ConsumerState<_CreateObjectDialog> createState() => _CreateObjectDialogState();
}

class _CreateObjectDialogState extends ConsumerState<_CreateObjectDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  GisCategory? _category;
  bool _saving = false;

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _category == null) return;
    setState(() => _saving = true);
    final cat = _category!;
    final obj = GisObject(
      id: 'obj_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: _descCtrl.text.trim(),
      category: cat,
      layers: const [],
      updatedAt: DateTime.now(),
      icon: cat.icon,
    );
    await ref.read(repoProvider).addObject(obj);
    ref.invalidate(objectsProvider);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(categoriesProvider);
    return AlertDialog(
      title: const Text('Новый объект', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      content: catsAsync.when(
        loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: AppColors.accent))),
        error: (e, _) => Text(e.toString()),
        data: (cats) => Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Название',
              labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<GisCategory>(
            value: _category,
            hint: const Text('Выберите категорию', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            items: cats.map((c) => DropdownMenuItem(value: c,
              child: Text(c.name, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _category = v),
            decoration: const InputDecoration(
              labelText: 'Категория',
              labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Описание (необязательно)',
              labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        ElevatedButton(
          onPressed: _saving || _category == null ? null : _submit,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Создать'),
        ),
      ],
    );
  }
}

class _ObjectSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [SkeletonBox(width: 42, height: 42, radius: 12), SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SkeletonBox(height: 14), SizedBox(height: 6), SkeletonBox(width: 100, height: 11)]))]),
        SizedBox(height: 10), SkeletonBox(height: 11), SizedBox(height: 6), SkeletonBox(width: 180, height: 11),
        SizedBox(height: 12), Row(children: [SkeletonBox(width: 80, height: 22, radius: 6), SizedBox(width: 8), SkeletonBox(width: 80, height: 22, radius: 6)]),
      ]),
    );
  }
}
