// lib/main.dart
// Единая точка входа GIS Monitor.
// Одно дерево виджетов. Один MaterialApp.router. Один ProviderScope.
// GoRouter управляет всей навигацией — auth flow + protected shell routes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'providers/app_providers.dart';
import 'routing/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: const GisApp(),
    ),
  );
}

/// Корневой виджет. Единственный MaterialApp во всём приложении.
/// Использует MaterialApp.router — GoRouter управляет стеком страниц.
class GisApp extends ConsumerWidget {
  const GisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Реактивно переключает тему — перестраивает только MaterialApp
    final isDark = ref.watch(isDarkProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'GIS Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
