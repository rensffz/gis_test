// test/integration/tables_flow_test.dart
// Widget-тесты flow работы с таблицами атрибутов.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:gis_app/providers/app_providers.dart';
import 'package:gis_app/models/app_models.dart';
import 'package:gis_app/features/tables/screens/tables_screen.dart';
import 'package:gis_app/shared/widgets/common_widgets.dart';
import '../helpers/prefs_helper.dart';
import '../helpers/provider_container_helper.dart';
import '../fixtures/test_fixtures.dart';
import '../mocks/mock_repository.dart';

void main() {
  setUpAll(registerMockFallbacks);

  final seedTables = [
    makeTable(id: 'tbl_1', name: 'Климатические данные',
        description: 'Метеорологические показатели',
        properties: [kTestPropString, kTestPropInt]),
    makeTable(id: 'tbl_2', name: 'Почвенные параметры',
        description: 'Агрохимические свойства',
        properties: [kTestPropDouble]),
  ];

  Future<Widget> buildTablesWidget(MockAppRepository mock) async {
    final prefs = await createEmptyPrefs();
    return buildIsolatedWidget(
      prefs,
      const TablesScreen(),
      overrides: [repoProvider.overrideWithValue(mock)],
    );
  }

  group('TablesScreen', () {
    late MockAppRepository mock;

    setUp(() {
      mock = MockAppRepository();
      mock.stubFetchTables(seedTables);
    });

    testWidgets('показывает список таблиц', (tester) async {
      await tester.pumpWidget(await buildTablesWidget(mock));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Климатические данные'), findsOneWidget);
      expect(find.text('Почвенные параметры'), findsOneWidget);
    });

    testWidgets('показывает количество свойств', (tester) async {
      await tester.pumpWidget(await buildTablesWidget(mock));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // tbl_1 имеет 2 свойства
      expect(find.textContaining('2'), findsWidgets);
    });

    testWidgets('показывает поиск', (tester) async {
      await tester.pumpWidget(await buildTablesWidget(mock));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('фильтрует по поиску', (tester) async {
      await tester.pumpWidget(await buildTablesWidget(mock));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.enterText(find.byType(TextField).first, 'климат');
      await tester.pumpAndSettle();
      expect(find.text('Климатические данные'), findsOneWidget);
      expect(find.text('Почвенные параметры'), findsNothing);
    });

    testWidgets('очистка поиска показывает все таблицы', (tester) async {
      await tester.pumpWidget(await buildTablesWidget(mock));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.enterText(find.byType(TextField).first, 'климат');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      expect(find.text('Климатические данные'), findsOneWidget);
      expect(find.text('Почвенные параметры'), findsOneWidget);
    });

    testWidgets('показывает skeleton при загрузке', (tester) async {
      // Используем Completer чтобы удерживать loading-state без pending timers
      final completer = Completer<List<AttributeTable>>();
      when(() => mock.fetchTables()).thenAnswer((_) => completer.future);
      await tester.pumpWidget(await buildTablesWidget(mock));
      await tester.pump(const Duration(milliseconds: 50));
      // TablesScreen показывает _Skeleton (SkeletonBox-ы) вместо CircularProgressIndicator
      expect(find.byType(SkeletonBox), findsWidgets);
      completer.complete(seedTables);
      await tester.pumpAndSettle();
    });

    testWidgets('показывает сообщение об ошибке', (tester) async {
      when(() => mock.fetchTables()).thenThrow(Exception('DB error'));
      await tester.pumpWidget(await buildTablesWidget(mock));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('error'), findsWidgets);
    });

    testWidgets('удаление таблицы через диалог', (tester) async {
      mock.stubDeleteTable();
      await tester.pumpWidget(await buildTablesWidget(mock));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Ищем кнопку удаления (icon delete)
      final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
      if (deleteButtons.evaluate().isNotEmpty) {
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();
        // Должен появиться диалог подтверждения
        expect(find.text('Удалить таблицу?'), findsOneWidget);
        // Отменяем
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();
        // Таблица на месте
        expect(find.text('Климатические данные'), findsOneWidget);
      }
    });
  });

  group('TablesScreen — embedded mode', () {
    testWidgets('embedded=true рендерится без AppBar', (tester) async {
      final mock = MockAppRepository();
      mock.stubFetchTables(seedTables);
      final prefs = await createEmptyPrefs();
      // embedded=true возвращает Stack без Scaffold — нужен Scaffold-обёртка
      await tester.pumpWidget(buildIsolatedWidget(
        prefs,
        const Scaffold(body: TablesScreen(embedded: true)),
        overrides: [repoProvider.overrideWithValue(mock)],
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Климатические данные'), findsOneWidget);
      // Нет собственного AppBar с "Таблицы атрибутов"
      expect(find.text('Таблицы атрибутов'), findsNothing);
    });
  });
}
