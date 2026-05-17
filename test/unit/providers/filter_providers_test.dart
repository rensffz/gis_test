// test/unit/providers/filter_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/material.dart';
import 'package:gis_app/providers/app_providers.dart';
import 'package:gis_app/models/app_models.dart';
import '../../helpers/provider_container_helper.dart';
import '../../fixtures/test_fixtures.dart';
import '../../mocks/mock_repository.dart';

void main() {
  setUpAll(registerMockFallbacks);

  group('filteredObjectsProvider', () {
    final cat1 = const GisCategory(id: 'cat_1', name: 'Категория 1', color: Color(0xFF00D4AA), icon: Icons.category);
    final cat2 = const GisCategory(id: 'cat_2', name: 'Категория 2', color: Color(0xFF3D8EF5), icon: Icons.category);
    final seedObjects = [
      makeGisObject(id: 'o1', name: 'Поле Пшеница', description: 'зерно', category: cat1),
      makeGisObject(id: 'o2', name: 'Водохранилище', description: 'вода', category: cat2),
      makeGisObject(id: 'o3', name: 'Пшеничное поле', description: 'урожай', category: cat1),
    ];

    ProviderContainer makeContainer() {
      final mock = MockAppRepository();
      when(() => mock.fetchObjects()).thenAnswer((_) async => seedObjects);
      final c = ProviderContainer(overrides: [repoProvider.overrideWithValue(mock)]);
      addTearDown(c.dispose);
      return c;
    }

    test('без фильтров возвращает все объекты', () async {
      final c = makeContainer();
      await c.read(objectsProvider.future);
      expect(c.read(filteredObjectsProvider).valueOrNull, hasLength(3));
    });

    group('поиск по тексту', () {
      test('фильтрует по имени (case-insensitive)', () async {
        final c = makeContainer();
        await c.read(objectsProvider.future);
        c.read(objectSearchProvider.notifier).state = 'пшен';
        expect(c.read(filteredObjectsProvider).valueOrNull, hasLength(2));
      });

      test('фильтрует по описанию', () async {
        final c = makeContainer();
        await c.read(objectsProvider.future);
        c.read(objectSearchProvider.notifier).state = 'вода';
        final result = c.read(filteredObjectsProvider).valueOrNull!;
        expect(result.length, equals(1));
        expect(result.first.id, equals('o2'));
      });

      test('пустой запрос — все объекты', () async {
        final c = makeContainer();
        await c.read(objectsProvider.future);
        c.read(objectSearchProvider.notifier).state = '';
        expect(c.read(filteredObjectsProvider).valueOrNull, hasLength(3));
      });

      test('запрос без совпадений — пустой список', () async {
        final c = makeContainer();
        await c.read(objectsProvider.future);
        c.read(objectSearchProvider.notifier).state = 'xyz_no_match';
        expect(c.read(filteredObjectsProvider).valueOrNull, isEmpty);
      });

      test('trim пробелов', () async {
        final c = makeContainer();
        await c.read(objectsProvider.future);
        c.read(objectSearchProvider.notifier).state = '  пшен  ';
        expect(c.read(filteredObjectsProvider).valueOrNull, hasLength(2));
      });
    });

    group('фильтрация по категории', () {
      test('фильтрует по cat_1', () async {
        final c = makeContainer();
        await c.read(objectsProvider.future);
        c.read(selectedCategoryProvider.notifier).state = 'cat_1';
        final result = c.read(filteredObjectsProvider).valueOrNull!;
        expect(result, hasLength(2));
        expect(result.every((o) => o.category.id == 'cat_1'), isTrue);
      });

      test('фильтрует по cat_2', () async {
        final c = makeContainer();
        await c.read(objectsProvider.future);
        c.read(selectedCategoryProvider.notifier).state = 'cat_2';
        final result = c.read(filteredObjectsProvider).valueOrNull!;
        expect(result, hasLength(1));
        expect(result.first.id, equals('o2'));
      });

      test('null категория — все объекты', () async {
        final c = makeContainer();
        await c.read(objectsProvider.future);
        c.read(selectedCategoryProvider.notifier).state = null;
        expect(c.read(filteredObjectsProvider).valueOrNull, hasLength(3));
      });
    });

    group('комбинированные фильтры', () {
      test('категория + поиск', () async {
        final c = makeContainer();
        await c.read(objectsProvider.future);
        c.read(selectedCategoryProvider.notifier).state = 'cat_1';
        c.read(objectSearchProvider.notifier).state = 'Поле Пшеница';
        final result = c.read(filteredObjectsProvider).valueOrNull!;
        expect(result, hasLength(1));
        expect(result.first.id, equals('o1'));
      });
    });
  });

  group('filteredTablesProvider', () {
    final seedTables = [
      makeTable(id: 'tbl_1', name: 'Климатические данные', description: 'метео'),
      makeTable(id: 'tbl_2', name: 'Почвенные параметры', description: 'агро'),
      makeTable(id: 'tbl_3', name: 'Геодезия', description: 'высоты'),
    ];

    ProviderContainer makeContainer() {
      final mock = MockAppRepository();
      mock.stubFetchTables(seedTables);
      final c = ProviderContainer(overrides: [repoProvider.overrideWithValue(mock)]);
      addTearDown(c.dispose);
      return c;
    }

    test('без фильтра — все таблицы', () async {
      final c = makeContainer();
      await awaitNotifierData(c, tablesProvider);
      expect(c.read(filteredTablesProvider).valueOrNull, hasLength(3));
    });

    test('фильтрует по имени', () async {
      final c = makeContainer();
      await awaitNotifierData(c, tablesProvider);
      c.read(tableSearchProvider.notifier).state = 'климат';
      expect(c.read(filteredTablesProvider).valueOrNull, hasLength(1));
    });

    test('фильтрует по описанию', () async {
      final c = makeContainer();
      await awaitNotifierData(c, tablesProvider);
      c.read(tableSearchProvider.notifier).state = 'агро';
      final result = c.read(filteredTablesProvider).valueOrNull!;
      expect(result.length, equals(1));
      expect(result.first.id, equals('tbl_2'));
    });

    test('пустой запрос — все таблицы', () async {
      final c = makeContainer();
      await awaitNotifierData(c, tablesProvider);
      c.read(tableSearchProvider.notifier).state = '';
      expect(c.read(filteredTablesProvider).valueOrNull, hasLength(3));
    });
  });

  group('filteredFilesProvider', () {
    final seedFiles = [
      makeFileWithObject(
        file: makeFile(id: 'f1', name: 'ortho_2024.tif'),
        objectId: 'obj_1', objectName: 'Поле А',
      ),
      makeFileWithObject(
        file: makeFile(id: 'f2', name: 'report.pdf'),
        objectId: 'obj_2', objectName: 'Водохранилище',
      ),
    ];

    ProviderContainer makeContainer() {
      final mock = MockAppRepository();
      mock.stubFetchAllFiles(seedFiles);
      final c = ProviderContainer(overrides: [repoProvider.overrideWithValue(mock)]);
      addTearDown(c.dispose);
      return c;
    }

    test('без фильтра — все файлы', () async {
      final c = makeContainer();
      await awaitNotifierData(c, allFilesProvider);
      expect(c.read(filteredFilesProvider).valueOrNull, hasLength(2));
    });

    test('фильтрует по имени файла', () async {
      final c = makeContainer();
      await awaitNotifierData(c, allFilesProvider);
      c.read(fileSearchProvider.notifier).state = 'ortho';
      expect(c.read(filteredFilesProvider).valueOrNull, hasLength(1));
    });

    test('фильтрует по имени объекта', () async {
      final c = makeContainer();
      await awaitNotifierData(c, allFilesProvider);
      c.read(fileSearchProvider.notifier).state = 'водо';
      final result = c.read(filteredFilesProvider).valueOrNull!;
      expect(result.length, equals(1));
      expect(result.first.file.id, equals('f2'));
    });
  });
}
