// lib/shared/widgets/common_widgets.dart
import 'package:flutter/material.dart';
import '../keys.dart';
import '../../core/app_theme.dart';

// ─── AppBar с Drawer-кнопкой ─────────────────────────────────
class GisAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? bottom;
  final bool showDrawer;
  final VoidCallback? onBack;

  const GisAppBar({
    super.key, required this.title, this.actions,
    this.bottom, this.showDrawer = false, this.onBack,
  });

  @override
  Size get preferredSize => Size.fromHeight(bottom != null ? kToolbarHeight + 48 : kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      leading: onBack != null
        ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: onBack)
        : showDrawer
          ? IconButton(
              icon: const Icon(Icons.menu_rounded, size: 22),
              onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
            )
          : null,
      title: Row(children: [
        if (showDrawer) ...[
          Container(width: 24, height: 24,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.terrain_rounded, size: 13, color: AppColors.accent),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
      ]),
      actions: actions,
      bottom: bottom != null
        ? PreferredSize(preferredSize: const Size.fromHeight(48), child: bottom!)
        : null,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
    );
  }
}

// ─── Skeleton box ─────────────────────────────────────────────
class SkeletonBox extends StatefulWidget {
  final double width, height, radius;
  const SkeletonBox({super.key, this.width = double.infinity, required this.height, this.radius = 8});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 0.7).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          color: (isDark ? AppColors.cardDark : AppColors.borderLight).withOpacity(_a.value),
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const AppEmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.bgLight,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Icon(icon, size: 32, color: isDark ? AppColors.textMuted : AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: TextStyle(fontSize: 14, height: 1.5,
                  color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

// ─── App Snackbar ─────────────────────────────────────────────
void showAppSnackbar(BuildContext context, String message, {bool isError = false, IconData? icon}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(icon ?? (isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded),
          color: isError ? AppColors.error : AppColors.accent, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14))),
    ]),
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 3),
  ));
}

// ─── Card container ───────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: onTap != null
          ? Material(color: Colors.transparent, borderRadius: BorderRadius.circular(16),
              child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
                splashColor: AppColors.accent.withOpacity(0.06),
                child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child)))
          : Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
    );
  }
}

// ─── Section header ───────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 10),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0,
            color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
          )),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}
