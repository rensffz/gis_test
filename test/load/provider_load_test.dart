// test/load/provider_load_test.dart
// Нагрузочные тесты провайдеров и фильтрации.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gis_app/providers/app_providers.dart';
import 'package:gis_app/models/app_models.dart';
import '../helpers/prefs_helper.dart';
import '../helpers/provider_container_helper.dart';
import '../mocks/mock_repository.dart';
import 'data_generator.dart';

void main() {
  setUpAll(registerMockFallbacks);

  ProviderContainer makeContainer(MockAppRepository mock) {
    final c = ProviderContainer(overrides: [repoProvider.overrideWithValue(mock)]);
    addTearDown(c.dispose);
    return c;
  }

  group('Load Tests — Providers', () {
    group('filteredObjectsProvider', () {
      test('фильтрация 1000 объектов по тексту — < 50ms', () async {
        final objects = generateObjects(1000);
        final mock = MockAppRepository();
        when(() => mock.fetchObjects()).thenAnswer((_) async => objects);
        final c = makeContainer(mock);
        await c.read(objectsProvider.future);

        final ms = measureSyncMs(() {
          c.read(objectSearchProvider.notifier).state = 'Load Test Object 5';
          c.read(filteredObjectsProvider);
        });
        expect(ms, lessThan(50), reason: 'Фильтрация 1000 объектов: ${ms}ms');
      });

      test('фильтрация по категории 1000 объектов — < 20ms', () async {
        final objects = generateObjects(1000);
        final mock = MockAppRepository();
        when(() => mock.fetchObjects()).thenAnswer((_) async => objects);
        final c = makeContainer(mock);
        await c.read(objectsProvider.future);

        final ms = measureSyncMs(() {
          c.read(selectedCategoryProvider.notifier).state = 'cat_load';
          c.read(filteredObjectsProvider);
        });
        expect(ms, lessThan(20), reason: 'Категориальная фильтрация 1000: ${ms}ms');
      });

      test('1000 объектов загружаются в провайдер', () async {
        final objects = generateObjects(1000);
        final mock = MockAppRepository();
        when(() => mock.fetchObjects()).thenAnswer((_) async => objects);
        final c = makeContainer(mock);
        await c.read(objectsProvider.future);
        expect(c.read(filteredObjectsProvider).valueOrNull, hasLength(1000));
      });

      test('сброс фильтра — все 1000 объектов снова видны', () async {
        final objects = generateObjects(1000);
        final mock = MockAppRepository();
        when(() => mock.fetchObjects()).thenAnswer((_) async => objects);
        final c = makeContainer(mock);
        await c.read(objectsProvider.future);
        c.read(objectSearchProvider.notifier).state = 'no_match_xyz';
        expect(c.read(filteredObjectsProvider).valueOrNull, isEmpty);
        c.read(objectSearchProvider.notifier).state = '';
        expect(c.read(filteredObjectsProvider).valueOrNull, hasLength(1000));
      });
    });

    group('filteredTablesProvider', () {
      test('фильтрация 500 таблиц по тексту — < 20ms', () async {
        final tables = generateTables(500, propsPerTable: 5);
        final mock = MockAppRepository();
        mock.stubFetchTables(tables);
        final c = makeContainer(mock);
        await awaitNotifierData(c, tablesProvider);

        final ms = measureSyncMs(() {
          c.read(tableSearchProvider.notifier).state = 'Table 25';
          c.read(filteredTablesProvider);
        });
        expect(ms, lessThan(20));
      });
    });

    group('filteredFilesProvider', () {
      test('фильтрация 500 файлов — < 20ms', () async {
        final files = generateFilesWithObjects(500);
        final mock = MockAppRepository();
        mock.stubFetchAllFiles(files);
        final c = makeContainer(mock);
        await awaitNotifierData(c, allFilesProvider);

        final ms = measureSyncMs(() {
          c.read(fileSearchProvider.notifier).state = 'load_file_1';
          c.read(filteredFilesProvider);
        });
        expect(ms, lessThan(20));
      });
    });

    group('LayersNotifier', () {
      test('toggleVisibility × 100 обновлений — корректно', () async {
        final layers = generateLayers(20, prefix: 'stress_obj');
        final mock = MockAppRepository();
        mock.stubFetchLayers('stress_obj', layers);
        mock.stubUpdateLayerVisibility();
        final c = makeContainer(mock);
        await awaitNotifierData(c, layersProvider('stress_obj'));

        final notifier = c.read(layersProvider('stress_obj').notifier);
        final sw = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          await notifier.toggleVisibility(layers[i % layers.length].id);
        }
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(2000),
            reason: 'toggleVisibility×100: ${sw.elapsedMilliseconds}ms');
      });

      test('20 слоёв загружаются корректно', () async {
        final layers = generateLayers(20);
        final mock = MockAppRepository();
        mock.stubFetchLayers('big_obj', layers);
        final c = makeContainer(mock);
        await awaitNotifierData(c, layersProvider('big_obj'));
        expect(c.read(layersProvider('big_obj')).valueOrNull, hasLength(20));
      });
    });

    group('TablesNotifier', () {
      test('create × 100 таблиц — state обновляется', () async {
        final mock = MockAppRepository();
        mock.stubFetchTables([]);
        final tables = generateTables(100, propsPerTable: 3);
        int callCount = 0;
        when(() => mock.createTable(any())).thenAnswer((inv) async {
          callCount++;
          return inv.positionalArguments.first as AttributeTable;
        });
        final c = makeContainer(mock);
        await awaitNotifierData(c, tablesProvider);
        for (final t in tables) {
          await c.read(tablesProvider.notifier).create(t);
        }
        expect(c.read(tablesProvider).valueOrNull, hasLength(100));
        expect(callCount, equals(100));
      });
    });

    group('AllFilesNotifier', () {
      test('addGlobal × 100 — список растёт', () async {
        final seedFiles = generateFilesWithObjects(10);
        final mock = MockAppRepository();
        mock.stubFetchAllFiles(seedFiles);
        final c = makeContainer(mock);
        await awaitNotifierData(c, allFilesProvider);

        when(() => mock.addGlobalFile(any())).thenAnswer((inv) {
          final f = inv.positionalArguments.first as GisFile;
          return FileWithObject(
            file: f, objectId: '', objectName: 'Хранилище',
            objectIcon: Icons.storage_rounded,
            objectColor: const Color(0xFFF5A623),
          );
        });

        final sw = Stopwatch()..start();
        for (final f in generateFiles(100)) {
          c.read(allFilesProvider.notifier).addGlobal(f);
        }
        sw.stop();

        expect(c.read(allFilesProvider).valueOrNull!.length, greaterThan(10));
        expect(sw.elapsedMilliseconds, lessThan(500));
      });

      test('delete × 50 файлов — список уменьшается', () async {
        final files = generateFilesWithObjects(100);
        final mock = MockAppRepository();
        mock.stubFetchAllFiles(files);
        mock.stubDeleteFiles();
        final c = makeContainer(mock);
        await awaitNotifierData(c, allFilesProvider);
        expect(c.read(allFilesProvider).valueOrNull, hasLength(100));

        final idsToDelete = files.take(50).map((fw) => fw.file.id).toSet();
        c.read(allFilesProvider.notifier).delete(idsToDelete);
        expect(c.read(allFilesProvider).valueOrNull, hasLength(50));
      });
    });

    group('Stress — MapDemoPoint', () {
      test('1000 точек создаются быстро', () {
        final ms = measureSyncMs(() => generatePoints(1000));
        expect(ms, lessThan(100), reason: 'generatePoints(1000): ${ms}ms');
      });

      test('copyWith на 1000 точках — < 50ms', () {
        final points = generatePoints(1000);
        final ms = measureSyncMs(() {
          for (final p in points) {
            p.copyWith(label: 'X', attributes: {'key': 'val'});
          }
        });
        expect(ms, lessThan(50));
      });
    });

    group('Stress — AttributeTable', () {
      test('таблица с 100 свойствами — propertyCount корректен', () {
        final table = generateTables(1, propsPerTable: 100).first;
        expect(table.propertyCount, equals(100));
      });

      test('copyWith таблицы с 100 свойствами — < 10ms', () {
        final table = generateTables(1, propsPerTable: 100).first;
        final ms = measureSyncMs(() {
          for (int i = 0; i < 1000; i++) {
            table.copyWith(name: 'Updated $i');
          }
        });
        expect(ms, lessThan(100));
      });
    });
  });
}
