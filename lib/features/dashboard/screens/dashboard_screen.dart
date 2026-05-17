// lib/features/dashboard/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/common_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final isDark = ref.watch(isDarkProvider);

    return Scaffold(
      appBar: GisAppBar(
        title: 'GIS Monitor',
        showDrawer: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
            onPressed: () => ref.read(isDarkProvider.notifier).state = !isDark,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WelcomeBanner(user: user, isDark: isDark, onTap: () => context.go(AppRoutes.profile)),
            SectionHeader(title: 'Навигация'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _QuickAction(label: 'GIS Объекты', icon: Icons.place_rounded,
                      color: AppColors.layerPoint, onTap: () => context.go(AppRoutes.objects)),
                  const SizedBox(height: 10),
                  _QuickAction(label: 'Таблицы', icon: Icons.table_rows_rounded,
                      color: AppColors.layerPolyline, onTap: () => context.go(AppRoutes.tables)),
                  const SizedBox(height: 10),
                  _QuickAction(label: 'Файлы', icon: Icons.folder_outlined,
                      color: AppColors.layerRaster, onTap: () => context.go(AppRoutes.files)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final dynamic user;
  final bool isDark;
  final VoidCallback? onTap;
  const _WelcomeBanner({required this.user, required this.isDark, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004D3D), AppColors.accentDim],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Добро пожаловать', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7), letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(user?.fullName ?? 'Пользователь',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(user?.organization ?? '',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          Container(width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: Center(child: Text(user?.initials ?? '?',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)))),
        ],
      ),
    ));
  }
}


class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
          child: Row(
            children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color)),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight)),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

