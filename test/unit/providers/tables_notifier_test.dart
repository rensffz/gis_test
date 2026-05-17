// test/unit/providers/tables_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gis_app/providers/app_providers.dart';
import 'package:gis_app/models/app_models.dart';
import '../../helpers/provider_container_helper.dart';
import '../../fixtures/test_fixtures.dart';
import '../../mocks/mock_repository.dart';

void main() {
  setUpAll(registerMockFallbacks);

  final seedTables = [
    makeTable(id: 'tbl_1', name: 'Таблица 1'),
    makeTable(id: 'tbl_2', name: 'Таблица 2'),
    makeTable(id: 'tbl_3', name: 'Таблица 3'),
  ];

  ProviderContainer makeContainer(MockAppRepository mock) {
    final container = ProviderContainer(
      overrides: [repoProvider.overrideWithValue(mock)],
    );
    addTearDown(container.dispose);
    return container;
  }

  // Хелпер: создаёт контейнер и дожидается загрузки
  Future<ProviderContainer> makeLoadedContainer(MockAppRepository mock) async {
    final c = makeContainer(mock);
    await awaitNotifierData(c, tablesProvider);
    return c;
  }

  group('TablesNotifier', () {
    late MockAppRepository mock;

    setUp(() {
      mock = MockAppRepository();
      mock.stubFetchTables(seedTables);
    });

    group('начальная загрузка', () {
      test('загружает таблицы', () async {
        final c = await makeLoadedContainer(mock);
        expect(c.read(tablesProvider).valueOrNull, hasLength(3));
      });

      test('начальное состояние — loading', () {
        final c = makeContainer(mock);
        expect(c.read(tablesProvider), isA<AsyncLoading>());
      });

      test('ошибка загрузки — AsyncError', () async {
        when(() => mock.fetchTables()).thenThrow(Exception('DB error'));
        final c = makeContainer(mock);
        await awaitNotifierData(c, tablesProvider);
        expect(c.read(tablesProvider), isA<AsyncError>());
      });
    });

    group('create', () {
      test('добавляет таблицу в начало списка', () async {
        final newTable = makeTable(id: 'tbl_new', name: 'Новая');
        mock.stubCreateTable(newTable);
        final c = await makeLoadedContainer(mock);
        await c.read(tablesProvider.notifier).create(newTable);
        final tables = c.read(tablesProvider).valueOrNull!;
        expect(tables.first.id, equals('tbl_new'));
        expect(tables.length, equals(4));
      });

      test('вызывает repo.createTable', () async {
        final newTable = makeTable(id: 'tbl_call');
        mock.stubCreateTable(newTable);
        final c = await makeLoadedContainer(mock);
        await c.read(tablesProvider.notifier).create(newTable);
        verify(() => mock.createTable(any())).called(1);
      });
    });

    group('update', () {
      test('заменяет таблицу в списке', () async {
        final updated = seedTables[0].copyWith(name: 'Обновлённая');
        mock.stubUpdateTable(updated);
        final c = await makeLoadedContainer(mock);
        await c.read(tablesProvider.notifier).update(updated);
        final tables = c.read(tablesProvider).valueOrNull!;
        expect(tables.firstWhere((t) => t.id == 'tbl_1').name, equals('Обновлённая'));
      });

      test('не меняет другие таблицы', () async {
        final updated = seedTables[0].copyWith(name: 'X');
        mock.stubUpdateTable(updated);
        final c = await makeLoadedContainer(mock);
        await c.read(tablesProvider.notifier).update(updated);
        final tables = c.read(tablesProvider).valueOrNull!;
        expect(tables.firstWhere((t) => t.id == 'tbl_2').name, equals('Таблица 2'));
        expect(tables.firstWhere((t) => t.id == 'tbl_3').name, equals('Таблица 3'));
      });
    });

    group('delete', () {
      test('удаляет таблицу из списка', () async {
        mock.stubDeleteTable();
        final c = await makeLoadedContainer(mock);
        await c.read(tablesProvider.notifier).delete('tbl_1');
        final tables = c.read(tablesProvider).valueOrNull!;
        expect(tables.any((t) => t.id == 'tbl_1'), isFalse);
        expect(tables.length, equals(2));
      });

      test('оптимистичное обновление: удаляет до вызова repo', () async {
        when(() => mock.deleteTable('tbl_1')).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        final c = await makeLoadedContainer(mock);
        final deleteFuture = c.read(tablesProvider.notifier).delete('tbl_1');
        // Сразу после вызова — уже удалено
        expect(c.read(tablesProvider).valueOrNull!.any((t) => t.id == 'tbl_1'), isFalse);
        await deleteFuture;
      });

      test('откатывает state при ошибке repo', () async {
        when(() => mock.deleteTable('tbl_1')).thenThrow(Exception('DB error'));
        final c = await makeLoadedContainer(mock);
        try {
          await c.read(tablesProvider.notifier).delete('tbl_1');
        } catch (_) {}
        final tables = c.read(tablesProvider).valueOrNull!;
        expect(tables.any((t) => t.id == 'tbl_1'), isTrue);
      });
    });

    group('reload', () {
      test('перезагружает данные', () async {
        final c = await makeLoadedContainer(mock);
        expect(c.read(tablesProvider).valueOrNull, hasLength(3));
        when(() => mock.fetchTables()).thenAnswer((_) async => [seedTables[0]]);
        await c.read(tablesProvider.notifier).reload();
        await awaitNotifierData(c, tablesProvider);
        expect(c.read(tablesProvider).valueOrNull, hasLength(1));
      });
    });
  });
}
