// lib/features/files/screens/files_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../models/app_models.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});
  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark          = ref.watch(isDarkProvider);
    final allFilesAsync   = ref.watch(allFilesProvider);
    final filteredAsync   = ref.watch(filteredFilesProvider);
    final selectedIds     = ref.watch(selectedFileIdsProvider);
    final query           = ref.watch(fileSearchProvider);

    final allFiles      = allFilesAsync.valueOrNull ?? [];
    final filteredFiles = filteredAsync.valueOrNull   ?? [];
    final hasSelection  = selectedIds.isNotEmpty;
    // "All selected" means every visible (filtered) file is checked.
    final allSelected   = filteredFiles.isNotEmpty &&
        filteredFiles.every((fw) => selectedIds.contains(fw.file.id));

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      floatingActionButton: hasSelection
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _AddFileSheet(isDark: isDark),
              ),
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bgDark,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Добавить',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
      appBar: GisAppBar(
        title: hasSelection ? '${selectedIds.length} выбрано' : 'Файлы',
        showDrawer: !hasSelection,
        onBack: hasSelection
            ? () => ref.read(selectedFileIdsProvider.notifier).state = {}
            : null,
        actions: [
          if (allFiles.isNotEmpty) ...[
            IconButton(
              icon: Icon(
                allSelected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: allSelected ? AppColors.accent : AppColors.textSecondary,
              ),
              onPressed: () {
                if (allSelected) {
                  ref.read(selectedFileIdsProvider.notifier).state = {};
                } else {
                  // Select all currently visible (filtered) files.
                  ref.read(selectedFileIdsProvider.notifier).state =
                      filteredFiles.map((fw) => fw.file.id).toSet();
                }
              },
              tooltip: allSelected ? 'Снять выбор' : 'Выбрать все',
            ),
            if (hasSelection) ...[
              IconButton(
                icon: const Icon(Icons.download_outlined,
                    size: 20, color: AppColors.accent),
                onPressed: () => _export(context, ref, selectedIds),
                tooltip: 'Экспорт',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppColors.error),
                onPressed: () => _confirmDelete(context, ref, selectedIds),
                tooltip: 'Удалить',
              ),
            ],
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: Column(
        children: [
          // Search bar — shown as soon as any files exist.
          if (allFiles.isNotEmpty)
            _SearchBar(
              controller: _searchCtrl,
              isDark: isDark,
              query: query,
              onChanged: (v) =>
                  ref.read(fileSearchProvider.notifier).state = v,
              onClear: () {
                _searchCtrl.clear();
                ref.read(fileSearchProvider.notifier).state = '';
              },
            ),
          Expanded(
            child: filteredAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent)),
              error: (e, _) => AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Ошибка загрузки',
                subtitle: e.toString(),
              ),
              data: (files) {
                if (allFiles.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.folder_outlined,
                    title: 'Нет файлов',
                    subtitle: 'Нажмите «Добавить» чтобы загрузить первый файл',
                  );
                }
                if (files.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Нет результатов',
                    subtitle: 'По запросу «$query» ничего не найдено',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final fw = files[i];
                    final selected = selectedIds.contains(fw.file.id);
                    return _FileCard(
                      fw: fw,
                      selected: selected,
                      isDark: isDark,
                      onToggle: () {
                        final next =
                            Set<String>.from(ref.read(selectedFileIdsProvider));
                        if (selected) {
                          next.remove(fw.file.id);
                        } else {
                          next.add(fw.file.id);
                        }
                        ref.read(selectedFileIdsProvider.notifier).state = next;
                      },
                      onDelete: hasSelection
                          ? null
                          : () => _confirmDelete(context, ref, {fw.file.id}),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.isDark,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: 'Поиск по файлу или объекту…',
            hintStyle:
                const TextStyle(fontSize: 13, color: AppColors.textMuted),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 17, color: AppColors.textMuted),
                    onPressed: onClear,
                    visualDensity: VisualDensity.compact,
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
          ),
        ),
      ),
    );
  }
}

// ─── Bulk action helpers ──────────────────────────────────────

void _export(BuildContext context, WidgetRef ref, Set<String> ids) {
  showAppSnackbar(
    context,
    'Экспорт ${ids.length} ${_pluralFiles(ids.length)}',
    icon: Icons.download_rounded,
  );
  ref.read(selectedFileIdsProvider.notifier).state = {};
}

Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, Set<String> ids) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      title: Text(
        ids.length == 1 ? 'Удалить файл?' : 'Удалить файлы?',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
        ),
      ),
      content: Text(
        'Будет удалено: ${ids.length} ${_pluralFiles(ids.length)}.',
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color:
              isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Отмена',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          child: const Text('Удалить'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    ref.read(allFilesProvider.notifier).delete(ids);
    ref.read(selectedFileIdsProvider.notifier).state = {};
    showAppSnackbar(
      context,
      'Удалено ${ids.length} ${_pluralFiles(ids.length)}',
      icon: Icons.delete_outline_rounded,
    );
  }
}

String _pluralFiles(int n) =>
    n == 1 ? 'файл' : (n >= 2 && n <= 4 ? 'файла' : 'файлов');

// ─── Add file bottom sheet ────────────────────────────────────

class _AddFileSheet extends ConsumerStatefulWidget {
  final bool isDark;
  const _AddFileSheet({required this.isDark});
  @override
  ConsumerState<_AddFileSheet> createState() => _AddFileSheetState();
}

class _AddFileSheetState extends ConsumerState<_AddFileSheet> {
  final _form     = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  FileType  _type = FileType.geotiff;
  GisObject? _obj;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_form.currentState!.validate()) return;
    final f = GisFile(
      id: 'gf_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      type: _type,
      sizeBytes: 1024 * 1024,
      createdAt: DateTime.now(),
    );
    final sm = ScaffoldMessenger.of(context);
    final msg = _obj == null
        ? '«${f.name}» добавлен в хранилище'
        : '«${f.name}» привязан к «${_obj!.name}»';
    if (_obj == null) {
      ref.read(allFilesProvider.notifier).addGlobal(f);
    } else {
      ref.read(allFilesProvider.notifier).addToObject(_obj!.id, f);
    }
    Navigator.pop(context);
    sm.showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline_rounded, color: AppColors.accent, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  InputDecoration _dec(String label, String hint) => InputDecoration(
    labelText: label, hintText: hint,
    labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    fillColor: widget.isDark ? AppColors.cardDark : AppColors.bgLight, filled: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: widget.isDark ? AppColors.borderDark : AppColors.borderLight)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final objects = ref.watch(objectsProvider).valueOrNull ?? [];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 34, height: 4, margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.add_rounded, size: 18, color: AppColors.accent)),
            const SizedBox(width: 10),
            Text('Добавить файл', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
            const Spacer(),
            IconButton(icon: Icon(Icons.close_rounded, size: 18,
                color: isDark ? AppColors.textMuted : AppColors.textSecondaryLight),
              onPressed: () => Navigator.pop(context), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: _dec('Название файла *',
                _type == FileType.geotiff ? 'survey.tif' : 'myfile.dat'),
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Введите название';
              final name = v.trim().toLowerCase();
              if (_type == FileType.geotiff &&
                  !name.endsWith('.tif') && !name.endsWith('.tiff')) {
                return 'Файл типа .tif должен заканчиваться на .tif';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            decoration: _dec('Описание', 'Краткое описание файла'),
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<FileType>(
            value: _type,
            decoration: _dec('Тип файла', ''),
            dropdownColor: isDark ? AppColors.cardDark : Colors.white,
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
            items: kAllowedFileTypes.map((t) => DropdownMenuItem(
              value: t,
              child: Row(children: [
                Icon(t.icon, size: 15, color: t.color),
                const SizedBox(width: 8),
                Text(t.label),
              ]),
            )).toList(),
            onChanged: (v) { if (v != null) setState(() => _type = v); },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<GisObject?>(
            value: _obj,
            decoration: _dec('Привязать к объекту', 'Только хранилище'),
            dropdownColor: isDark ? AppColors.cardDark : Colors.white,
            style: TextStyle(fontSize: 13, color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight),
            items: [
              DropdownMenuItem<GisObject?>(
                value: null,
                child: Row(children: [
                  const Icon(Icons.storage_rounded, size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text('Только хранилище',
                      style: TextStyle(color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)),
                ]),
              ),
              ...objects.map((o) => DropdownMenuItem<GisObject?>(
                value: o,
                child: Row(children: [
                  Icon(o.icon, size: 15, color: o.category.color),
                  const SizedBox(width: 8),
                  Flexible(child: Text(o.name, overflow: TextOverflow.ellipsis)),
                ]),
              )),
            ],
            onChanged: (v) => setState(() => _obj = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            child: Text(_obj == null ? 'Добавить в хранилище' : 'Привязать к объекту'),
          ),
        ])),
        ),
      ),
    );
  }
}

// ─── File card ────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  final FileWithObject fw;
  final bool selected;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;
  const _FileCard({
    required this.fw,
    required this.selected,
    required this.isDark,
    required this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accent.withOpacity(0.06)
          : isDark
              ? AppColors.cardDark
              : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.accent.withOpacity(0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.accent.withOpacity(0.4)
                  : isDark
                      ? AppColors.borderDark
                      : AppColors.borderLight,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // ── Checkbox ───────────────────────────────────
              Checkbox(
                value: selected,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                side: BorderSide(
                  color: selected
                      ? AppColors.accent
                      : isDark
                          ? AppColors.textMuted
                          : AppColors.borderLight,
                  width: 1.5,
                ),
              ),
              const SizedBox(width: 10),
              // ── File type icon ─────────────────────────────
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: fw.file.type.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: fw.file.type.color.withOpacity(0.25)),
                ),
                child: Icon(fw.file.type.icon,
                    color: fw.file.type.color, size: 20),
              ),
              const SizedBox(width: 12),
              // ── Name + type + object ───────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fw.file.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: fw.file.type.color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            fw.file.type.label,
                            style: TextStyle(
                              fontSize: 9,
                              color: fw.file.type.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(fw.objectIcon,
                            size: 10, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            fw.objectName,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── File size ──────────────────────────────────
              Text(
                fw.file.sizeLabel,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
              // ── Single-file delete ─────────────────────────
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 17,
                        color: AppColors.error.withOpacity(0.65)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
