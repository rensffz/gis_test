// lib/shared/widgets/app_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../routing/app_router.dart';
import '../../models/app_models.dart';
import '../keys.dart';


class AppShell extends ConsumerWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: shellScaffoldKey,
      drawer: _AppDrawer(location: location),
      body: child,
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  final String location;
  const _AppDrawer({required this.location});

  static const _items = [
    _NavItem(AppRoutes.dashboard, Icons.dashboard_rounded,      'Главная'),
    _NavItem(AppRoutes.objects,   Icons.place_rounded,          'GIS Объекты'),
    _NavItem(AppRoutes.tables,    Icons.table_rows_rounded,     'Таблицы'),
    _NavItem(AppRoutes.files,     Icons.folder_outlined,        'Файлы'),
    _NavItem(AppRoutes.profile,   Icons.person_outline_rounded, 'Профиль'),
    _NavItem(AppRoutes.settings,  Icons.sync_rounded,           'Синхронизация', enabled: false),
  ];

  bool _isActive(String route) => location.startsWith(route);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final isDark = ref.watch(isDarkProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────
            _DrawerHeader(user: user),
            const SizedBox(height: 8),

            // ── Nav items ────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: _items.map((item) {
                  final active = _isActive(item.route);
                  return _DrawerTile(
                    item: item,
                    active: active,
                    onTap: item.enabled ? () {
                      Navigator.pop(context);
                      context.go(item.route);
                    } : null,
                  );
                }).toList(),
              ),
            ),

            const Divider(color: AppColors.dividerDark, height: 1),

            // ── Theme toggle ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      size: 18, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Text(isDark ? 'Тёмная тема' : 'Светлая тема',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const Spacer(),
                  Switch(
                    value: isDark,
                    onChanged: (v) => ref.read(isDarkProvider.notifier).state = v,
                  ),
                ],
              ),
            ),

            // ── Logout ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                ),
                title: const Text('Выйти',
                    style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).logout();
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  final AppUser? user;
  const _DrawerHeader({this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1520), AppColors.surfaceDark],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent, AppColors.accentDim],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user?.initials ?? '?',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(user?.fullName ?? 'Гость',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(user?.organization ?? '',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback? onTap;
  const _DrawerTile({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap != null ? 1.0 : 0.4,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.accent.withOpacity(0.25) : Colors.transparent,
          ),
        ),
        child: ListTile(
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: active ? AppColors.accent.withOpacity(0.15) : AppColors.cardDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon,
              size: 18, color: active ? AppColors.accent : AppColors.textSecondary),
          ),
          title: Text(item.label,
            style: TextStyle(
              fontSize: 14, fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? AppColors.accent : AppColors.textPrimary,
            )),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          dense: true,
        ),
      ),
    );
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final String label;
  final bool enabled;
  const _NavItem(this.route, this.icon, this.label, {this.enabled = true});
}
