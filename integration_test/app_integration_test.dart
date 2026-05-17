// integration_test/app_integration_test.dart
// E2E тесты на реальном устройстве/эмуляторе.
// Запуск: flutter test integration_test/ --device-id=<device>
//
// Эти тесты требуют запущенного устройства или эмулятора.
// В CI они не запускаются автоматически без подключённого эмулятора.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gis_app/main.dart' as app;
import 'package:gis_app/providers/app_providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E — Auth Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Полный цикл: логин → dashboard → logout', (tester) async {
      // Запускаем приложение
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const _TestApp(),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Должны быть на экране логина
      expect(find.text('GIS Monitor'), findsOneWidget);
      expect(find.text('Войдите в систему'), findsOneWidget);

      // Вводим данные
      await tester.enterText(find.byType(TextFormField).first, 'admin');
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Должны быть на Dashboard
      expect(find.text('Войдите в систему'), findsNothing);
    });

    testWidgets('Регистрация → логин', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const _TestApp(),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Переходим на регистрацию
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Step 1 — ввод пароля и основных данных
      expect(find.text('Создайте аккаунт'), findsOneWidget);
    });
  });

  group('E2E — Tables', () {
    testWidgets('Открытие раздела Таблицы', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const _TestApp(),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Логинимся
      await tester.enterText(find.byType(TextFormField).first, 'admin');
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Таблицы доступны из бокового меню или нижней навигации
      // Находим иконку таблиц
      final tableIcon = find.byIcon(Icons.table_rows_rounded);
      if (tableIcon.evaluate().isNotEmpty) {
        await tester.tap(tableIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
    });
  });
}

// Минимальный тестовый виджет-обёртка
class _TestApp extends ConsumerWidget {
  const _TestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'GIS Test',
      //routerConfig: ref.watch(routerProvider),
    );
  }
}
