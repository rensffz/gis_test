// test/helpers/provider_container_helper.dart
// Фабрики ProviderContainer и тестового виджета с ProviderScope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gis_app/providers/app_providers.dart';
import 'package:gis_app/routing/app_router.dart';
import 'package:gis_app/core/app_theme.dart';

/// Создаёт ProviderContainer с переопределением prefsProvider.
/// Автоматически добавляет tearDown для dispose.
ProviderContainer createContainer(
  SharedPreferences prefs, {
  List<Override> extraOverrides = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      ...extraOverrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Возвращает виджет с полным ProviderScope + MaterialApp.router.
/// Используется для widget/integration тестов.
Widget buildTestApp(SharedPreferences prefs, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      ...overrides,
    ],
    child: const _TestGisApp(),
  );
}

class _TestGisApp extends ConsumerWidget {
  const _TestGisApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'GIS Test',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}

/// Минимальное тестовое окружение без GoRouter.
/// Используется для тестирования отдельных виджетов.
Widget buildIsolatedWidget(
  SharedPreferences prefs,
  Widget child, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: child,
    ),
  );
}

/// Ожидает пока StateNotifierProvider<N, AsyncValue<T>> перестанет грузиться.
/// Используется вместо .future (которого нет у StateNotifierProvider в Riverpod 2).
///
/// Пример:
///   final c = makeContainer(mock);
///   await awaitNotifierData(c, tablesProvider);
///   expect(c.read(tablesProvider).valueOrNull, isNotNull);
Future<void> awaitNotifierData<T>(
    ProviderContainer c,
    ProviderListenable<AsyncValue<T>> provider, {
    Duration timeout = const Duration(seconds: 3),
}) async {
  final sw = Stopwatch()..start();
  // Читаем провайдер, чтобы инициализировать нотификатор
  c.read(provider);
  while (sw.elapsed < timeout) {
    final state = c.read(provider);
    if (!state.isLoading) return;
    await Future.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('Provider still loading after ${timeout.inMilliseconds}ms');
}
