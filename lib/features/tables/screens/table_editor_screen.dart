// lib/features/tables/screens/table_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../models/app_models.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../../routing/app_router.dart';

class TableEditorScreen extends ConsumerStatefulWidget {
  final String? tableId;
  const TableEditorScreen({super.key, this.tableId});
  @override
  ConsumerState<TableEditorScreen> createState() => _TableEditorScreenState();
}

class _TableEditorScreenState extends ConsumerState<TableEditorScreen> {
  final _form   = GlobalKey<FormState>();
  final _scroll  = ScrollController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<_EP> _props = [];
  bool _saving = false, _loaded = false;
  AttributeTable? _existing;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    if (widget.tableId == null) { setState(() => _loaded = true); return; }
    // StateNotifierProvider — read value synchronously (already loaded from initState)
    // Give it a tick to ensure tablesProvider has loaded, then read
    await Future.delayed(const Duration(milliseconds: 50));
    final t = (ref.read(tablesProvider).valueOrNull ?? []).where((x) => x.id == widget.tableId).firstOrNull;
    if (t != null && mounted) {
      _existing = t;
      _nameCtrl.text = t.name;
      _descCtrl.text = t.description;
      for (final p in t.properties) _props.add(_EP.from(p));
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() { _scroll.dispose(); _nameCtrl.dispose(); _descCtrl.dispose(); for (final p in _props) p.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    for (final p in _props) { if (p.nm.text.trim().isEmpty) { showAppSnackbar(context, 'Заполните название всех свойств', isError: true); return; } }
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 350));
    final t = AttributeTable(
      id: _existing?.id ?? 'tbl_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(), description: _descCtrl.text.trim(), updatedAt: DateTime.now(),
      properties: _props.map((p) => AttributeProperty(id: p.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}',
          name: p.nm.text.trim(), description: p.ds.text.trim(), measurementUnit: p.un.text.trim(), dataType: p.dataType)).toList(),
    );
    if (_existing == null) { await ref.read(tablesProvider.notifier).create(t); }
    else { await ref.read(tablesProvider.notifier).update(t); }
    if (mounted) { context.go(AppRoutes.tables); showAppSnackbar(context, _existing == null ? '«${t.name}» создана' : '«${t.name}» обновлена'); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_loaded) return Scaffold(appBar: GisAppBar(title: _existing == null ? 'Новая таблица' : 'Редактировать'),
      body: const Center(child: CircularProgressIndicator(color: AppColors.accent)));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (did, _) async {
        if (did) return;
        final leave = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          title: Text('Отменить изменения?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
          content: Text('Несохранённые данные будут потеряны.', style: TextStyle(fontSize: 13, color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Продолжить', style: TextStyle(color: AppColors.accent))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Выйти', style: TextStyle(color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight))),
          ],
        ));
        if ((leave ?? false) && context.mounted) context.go(AppRoutes.tables);
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
        appBar: GisAppBar(
          title: _existing == null ? 'Новая таблица' : 'Редактировать таблицу',
          onBack: () => context.go(AppRoutes.tables),
          actions: [
            Padding(padding: const EdgeInsets.only(right: 14), child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark,
                minimumSize: const Size(76, 34), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgDark)) : const Text('Сохранить'),
            )),
          ],
        ),
        body: Form(
          key: _form,
          child: CustomScrollView(controller: _scroll, slivers: [
            SliverToBoxAdapter(child: _sec('Основная информация', isDark, Column(children: [
              TextFormField(controller: _nameCtrl,
                decoration: _inp('Название таблицы', 'Климатические показатели'),
                style: TextStyle(color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _descCtrl, maxLines: 3,
                decoration: _inp('Описание', 'Краткое описание таблицы'),
                style: TextStyle(color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
            ]))),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(18, 6, 18, 8), child: Row(children: [
              Text('СВОЙСТВА', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8,
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(10)),
                child: Text('${_props.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent))),
              const Spacer(),
              InkWell(
                onTap: () {
                  setState(() => _props.add(_EP.empty()));
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scroll.hasClients) {
                      _scroll.animateTo(
                        _scroll.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(width: 28, height: 28,
                  decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_rounded, size: 16, color: AppColors.accent)),
              ),
            ]))),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _props.isEmpty
                  ? SliverToBoxAdapter(child: _EmptyProps(isDark: isDark))
                  : SliverList(delegate: SliverChildBuilderDelegate((_, i) => _PropCard(key: ValueKey(_props[i].key), p: _props[i], idx: i, isDark: isDark,
                    onDel: () => setState(() => _props.removeAt(i))), childCount: _props.length)),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ]),
        ),
      ),
    );
  }

  Widget _sec(String title, bool isDark, Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8,
            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight))),
      Container(decoration: BoxDecoration(color: isDark ? AppColors.cardDark : Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight)), padding: const EdgeInsets.all(15), child: child),
    ]));

  InputDecoration _inp(String l, String h) => InputDecoration(
    labelText: l, hintText: h,
    labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12));
}

// ── Editable property ─────────────────────────────────────────
class _EP {
  final String key;
  final String? id;
  final TextEditingController nm, ds, un;
  DataType dataType;
  _EP({required this.key, this.id, required this.nm, required this.ds, required this.un, this.dataType = DataType.string});
  factory _EP.empty() => _EP(key: UniqueKey().toString(), nm: TextEditingController(), ds: TextEditingController(), un: TextEditingController());
  factory _EP.from(AttributeProperty p) => _EP(key: p.id, id: p.id, nm: TextEditingController(text: p.name), ds: TextEditingController(text: p.description), un: TextEditingController(text: p.measurementUnit), dataType: p.dataType);
  void dispose() { nm.dispose(); ds.dispose(); un.dispose(); }
}

class _PropCard extends StatefulWidget {
  final _EP p; final int idx; final bool isDark; final VoidCallback onDel;
  const _PropCard({super.key, required this.p, required this.idx, required this.isDark, required this.onDel});
  @override State<_PropCard> createState() => _PropCardState();
}

class _PropCardState extends State<_PropCard> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _f;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _f = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _c.forward();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  InputDecoration _fd(String l, String h) => InputDecoration(labelText: l, hintText: h,
    labelStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
    hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    fillColor: widget.isDark ? AppColors.surfaceDark : AppColors.bgLight, filled: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: widget.isDark ? AppColors.borderDark : AppColors.borderLight)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: widget.isDark ? AppColors.borderDark : AppColors.borderLight)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: AppColors.accent, width: 1.5)));

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _f,
    child: Container(margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(color: widget.isDark ? AppColors.cardDark : Colors.white, borderRadius: BorderRadius.circular(13),
        border: Border.all(color: widget.isDark ? AppColors.borderDark : AppColors.borderLight)),
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 20, height: 20, decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
            child: Center(child: Text('${widget.idx+1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent)))),
          const Spacer(),
          InkWell(onTap: widget.onDel, borderRadius: BorderRadius.circular(5),
            child: Padding(padding: const EdgeInsets.all(3), child: Icon(Icons.close_rounded, size: 15, color: AppColors.error))),
        ]),
        const SizedBox(height: 9),
        TextFormField(controller: widget.p.nm,
          decoration: _fd('Название *', 'Температура воздуха'),
          style: TextStyle(fontSize: 13, color: widget.isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null),
        const SizedBox(height: 8),
        TextFormField(controller: widget.p.ds, decoration: _fd('Описание', 'Краткое описание'),
          style: TextStyle(fontSize: 12, color: widget.isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(flex: 3, child: DropdownButtonFormField<DataType>(
            value: widget.p.dataType,
            decoration: _fd('Тип данных', ''),
            style: TextStyle(fontSize: 12, color: widget.isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
            dropdownColor: widget.isDark ? AppColors.cardDark : Colors.white,
            items: DataType.values.map((t) => DropdownMenuItem(
              value: t,
              child: Text(t.label, style: const TextStyle(fontSize: 12)),
            )).toList(),
            onChanged: (v) { if (v != null) setState(() => widget.p.dataType = v); },
          )),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: TextFormField(controller: widget.p.un, decoration: _fd('Ед. изм.', '°C, %, м'),
            style: TextStyle(fontSize: 12, color: widget.isDark ? AppColors.textPrimary : AppColors.textPrimaryLight))),
        ]),
      ])));
}

class _EmptyProps extends StatelessWidget {
  final bool isDark;
  const _EmptyProps({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: isDark ? AppColors.cardDark : Colors.white, borderRadius: BorderRadius.circular(13),
      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
    child: Column(children: [
      Icon(Icons.add_chart_rounded, size: 34, color: isDark ? AppColors.textMuted : AppColors.textSecondaryLight),
      const SizedBox(height: 8),
      Text('Нет свойств', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)),
      const SizedBox(height: 3),
      Text('Нажмите + чтобы добавить свойство', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMuted : AppColors.textSecondaryLight), textAlign: TextAlign.center),
    ]));
}
