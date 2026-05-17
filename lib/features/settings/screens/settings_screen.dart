// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/common_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: GisAppBar(title: 'Синхронизация', showDrawer: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeader(title: 'Интерфейс'),
          AppCard(child: _SettingTile(
            icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            title: 'Тема', subtitle: isDark ? 'Тёмная тема' : 'Светлая тема',
            trailing: Switch(value: isDark, onChanged: (v) => ref.read(isDarkProvider.notifier).state = v))),
          SectionHeader(title: 'Данные'),
          AppCard(child: Column(children: [
            _SettingTile(icon: Icons.sync_rounded, title: 'Синхронизация', subtitle: 'Будет реализована позже',
              onTap: () => showAppSnackbar(context, 'Синхронизация будет реализована', icon: Icons.info_outline_rounded)),
            Divider(height: 1, color: isDark ? AppColors.dividerDark : AppColors.borderLight),
            _SettingTile(icon: Icons.storage_rounded, title: 'Локальная БД', subtitle: 'Mock · Drift будет добавлен',
              onTap: () => showAppSnackbar(context, 'Drift интеграция будет добавлена', icon: Icons.info_outline_rounded)),
          ])),
          SectionHeader(title: 'Аккаунт'),
          AppCard(child: _SettingTile(icon: Icons.person_outline_rounded, title: 'Профиль', subtitle: 'Редактировать данные', onTap: () => context.go(AppRoutes.profile))),
          const SizedBox(height: 8),
          AppCard(child: _SettingTile(icon: Icons.logout_rounded, title: 'Выйти', subtitle: 'Завершить сессию', color: AppColors.error,
            onTap: () => ref.read(authProvider.notifier).logout())),
          const SizedBox(height: 32),
          const Center(child: Text('GIS Monitor v1.0.0', style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color color;
  const _SettingTile({required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: color)),
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted) : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
