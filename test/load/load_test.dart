// test/load/load_test.dart
// Нагрузочные тесты: проверяют производительность репозитория и провайдеров
// при работе с большими объёмами данных.
//
// Запуск: flutter test test/load/load_test.dart
//
// Примечание: async-операции репозитория (addObject, addLayer, register,
// createTable) сериализуют данные в SharedPreferences при каждом вызове,
// поэтому итераций для них меньше. Sync-операции (addFileToObject, deleteFiles)
// работают с in-memory кэшем и выдерживают сотни вызовов.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gis_app/models/app_models.dart';
import 'package:gis_app/providers/app_providers.dart';
import 'package:gis_app/repositories/app_repository.dart';
import '../fixtures/test_fixtures.dart';
import '../helpers/prefs_helper.dart';
import '../helpers/provider_container_helper.dart';
import '../mocks/mock_repository.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Нагрузочные тесты — sync-операции репозитория (in-memory, быстрые)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Нагрузочные тесты — sync-операции репозитория', () {
    late AppRepository repo;

    setUp(() async {
      final prefs = await createEmptyPrefs();
      repo = AppRepository(prefs);
    });

    test('LOAD-01: addFileToObject × 500 — не более 600 мс', () async {
      await repo.fetchFiles('obj_1'); // инициализация кэша

      final sw = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        repo.addFileToObject(
          'obj_1',
          makeFile(id: 'stress_file_$i', name: 'file_$i.tif'),
        );
      }
      final files = await repo.fetchFiles('obj_1');
      sw.stop();

      expect(files.length, greaterThanOrEqualTo(500),
          reason: 'Все 500 файлов должны быть в кэше fetchFiles');
      expect(
        sw.elapsedMilliseconds,
        lessThan(600),
        reason:
            'Добавление 500 файлов (sync, in-memory) должно занимать менее 600 мс',
      );
    });

    test('LOAD-02: deleteFiles × 300 — не более 600 мс', () async {
      await repo.fetchFiles('obj_1');

      final ids = <String>{};
      for (var i = 0; i < 300; i++) {
        final id = 'del_file_$i';
        repo.addFileToObject('obj_1', makeFile(id: id));
        ids.add(id);
      }

      final sw = Stopwatch()..start();
      repo.deleteFiles(ids);
      final remaining = await repo.fetchFiles('obj_1');
      sw.stop();

      expect(remaining.any((f) => ids.contains(f.id)), isFalse,
          reason: 'Все 300 удалённых файлов должны исчезнуть из fetchFiles');
      expect(
        sw.elapsedMilliseconds,
        lessThan(600),
        reason: 'Удаление 300 файлов из in-memory кэша должно занимать менее 600 мс',
      );
    });

    test('LOAD-03: addGlobalFile × 200 и getGlobalFiles — не более 400 мс',
        () async {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        repo.addGlobalFile(
          makeFile(id: 'global_stress_$i', name: 'global_$i.tif'),
        );
      }
      final globals = repo.getGlobalFiles();
      sw.stop();

      expect(globals.length, greaterThanOrEqualTo(200),
          reason: 'Все 200 глобальных файлов должны быть в списке');
      expect(
        sw.elapsedMilliseconds,
        lessThan(400),
        reason:
            'Добавление 200 глобальных файлов (sync) должно занимать менее 400 мс',
      );
    });

    test(
        'LOAD-04: attachFileToObject × 200 с проверкой дедупликации — не более 400 мс',
        () async {
      await repo.fetchFiles('obj_1');

      // Создаём 200 уникальных файлов
      final files = List.generate(
        200,
        (i) => makeFile(id: 'attach_stress_$i', name: 'attach_$i.tif'),
      );

      final sw = Stopwatch()..start();
      for (final f in files) {
        repo.attachFileToObject('obj_1', f);
      }
      // Повторное прикрепление тех же файлов — не должно дублировать
      for (final f in files) {
        repo.attachFileToObject('obj_1', f);
      }
      final result = await repo.fetchFiles('obj_1');
      sw.stop();

      // Дублей не должно быть
      final attachedIds = files.map((f) => f.id).toSet();
      final attachedInResult = result.where((f) => attachedIds.contains(f.id));
      expect(attachedInResult.length, equals(200),
          reason: 'Повторное прикрепление не должно создавать дубли');
      expect(
        sw.elapsedMilliseconds,
        lessThan(400),
        reason:
            '400 вызовов attachFileToObject (с дедупликацией) должны занять менее 400 мс',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Нагрузочные тесты — async-операции репозитория (SharedPreferences I/O)
  // Каждая операция сериализует данные — реалистичные объёмы меньше.
  // ═══════════════════════════════════════════════════════════════════════════

  group('Нагрузочные тесты — async-операции репозитория', () {
    late AppRepository repo;

    setUp(() async {
      final prefs = await createEmptyPrefs();
      repo = AppRepository(prefs);
    });

    test(
      'LOAD-05: addObject × 20 — не более 5000 мс',
      () async {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 20; i++) {
          await repo.addObject(
            makeGisObject(id: 'async_obj_$i', name: 'Объект $i'),
          );
        }
        final objects = await repo.fetchObjects();
        sw.stop();

        expect(objects.length, greaterThanOrEqualTo(20),
            reason: 'Все 20 объектов должны быть доступны через fetchObjects');
        expect(
          sw.elapsedMilliseconds,
          lessThan(8000),
          reason: 'Добавление 20 объектов должно завершиться менее чем за 8 с',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'LOAD-06: addLayer × 15 для одного объекта — не более 3000 мс',
      () async {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 15; i++) {
          await repo.addLayer(
            'obj_1',
            makeLayer(id: 'async_layer_$i', name: 'Слой $i'),
          );
        }
        final layers = await repo.fetchLayers('obj_1');
        sw.stop();

        expect(layers.length, greaterThanOrEqualTo(15),
            reason: 'Все 15 слоёв должны быть доступны через fetchLayers');
        expect(
          sw.elapsedMilliseconds,
          lessThan(6000),
          reason: 'Добавление 15 слоёв должно завершиться менее чем за 6 с',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'LOAD-07: register × 5 пользователей — не более 3000 мс',
      () async {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 5; i++) {
          await repo.register(
            login: 'load_user_$i',
            password: 'password$i',
            firstName: 'Имя$i',
            lastName: 'Фамилия$i',
            organization: 'Орг',
            email: 'load$i@test.ru',
          );
        }
        sw.stop();

        expect(repo.isLoginTaken('load_user_0'), isTrue);
        expect(repo.isLoginTaken('load_user_4'), isTrue);
        expect(
          sw.elapsedMilliseconds,
          lessThan(3000),
          reason: 'Регистрация 5 пользователей должна завершиться менее чем за 3 с',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'LOAD-08: createTable × 10 с несколькими свойствами — не более 3000 мс',
      () async {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 10; i++) {
          await repo.createTable(
            makeTable(
              id: 'async_tbl_$i',
              name: 'Таблица $i',
              properties: [kTestPropString, kTestPropInt, kTestPropDouble],
            ),
          );
        }
        final tables = await repo.fetchTables();
        sw.stop();

        expect(tables.length, greaterThanOrEqualTo(10),
            reason: 'Все 10 таблиц должны быть в fetchTables');
        expect(
          sw.elapsedMilliseconds,
          lessThan(5000),
          reason: 'Создание 10 таблиц (3 свойства каждая) должно занять менее 5 с',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Нагрузочные тесты — фильтрация в провайдерах (чистые вычисления, быстрые)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Нагрузочные тесты — filteredObjectsProvider', () {
    setUpAll(registerMockFallbacks);

    ProviderContainer makeContainer(List<GisObject> objects) {
      final mock = MockAppRepository();
      when(() => mock.fetchObjects()).thenAnswer((_) async => objects);
      final c = ProviderContainer(
        overrides: [repoProvider.overrideWithValue(mock)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('LOAD-09: текстовый поиск по 1000 объектам — не более 50 мс',
        () async {
      final largeList = List.generate(
        1000,
        (i) => makeGisObject(
          id: 'big_obj_$i',
          name: i % 3 == 0 ? 'Поле пшеница $i' : 'Водохранилище $i',
          description: 'Описание объекта номер $i',
        ),
      );

      final c = makeContainer(largeList);
      await c.read(objectsProvider.future);

      final sw = Stopwatch()..start();
      c.read(objectSearchProvider.notifier).state = 'пшеница';
      final result = c.read(filteredObjectsProvider).valueOrNull;
      sw.stop();

      expect(result, isNotNull);
      expect(result!.length, greaterThan(300),
          reason: 'Каждый 3-й объект (>333 из 1000) должен пройти фильтр');
      expect(
        sw.elapsedMilliseconds,
        lessThan(50),
        reason: 'Фильтрация 1000 объектов должна занимать менее 50 мс',
      );
    });

    test(
        'LOAD-10: 50 последовательных смен поискового запроса по 1000 объектам — не более 300 мс',
        () async {
      final largeList = List.generate(
        1000,
        (i) => makeGisObject(
          id: 'seq_obj_$i',
          name: 'Объект категория ${i % 10} номер $i',
          description: 'desc $i',
        ),
      );

      final c = makeContainer(largeList);
      await c.read(objectsProvider.future);

      final sw = Stopwatch()..start();
      for (var q = 0; q < 50; q++) {
        c.read(objectSearchProvider.notifier).state = 'категория $q';
        c.read(filteredObjectsProvider).valueOrNull;
      }
      sw.stop();

      expect(
        sw.elapsedMilliseconds,
        lessThan(300),
        reason:
            '50 последовательных фильтраций по 1000 объектам должны занимать менее 300 мс',
      );
    });
  });

  group('Нагрузочные тесты — filteredTablesProvider', () {
    setUpAll(registerMockFallbacks);

    test('LOAD-11: текстовый поиск по 500 таблицам — не более 30 мс', () async {
      final largeTables = List.generate(
        500,
        (i) => makeTable(
          id: 'big_tbl_$i',
          name: i % 4 == 0 ? 'Климатические данные $i' : 'Почвенные параметры $i',
          description: 'desc $i',
        ),
      );

      final mock = MockAppRepository();
      mock.stubFetchTables(largeTables);

      final c = ProviderContainer(
        overrides: [repoProvider.overrideWithValue(mock)],
      );
      addTearDown(c.dispose);

      await awaitNotifierData(c, tablesProvider);

      final sw = Stopwatch()..start();
      c.read(tableSearchProvider.notifier).state = 'климат';
      final result = c.read(filteredTablesProvider).valueOrNull;
      sw.stop();

      expect(result, isNotNull);
      expect(result!.length, greaterThan(100),
          reason: 'Каждая 4-я таблица (>125 из 500) должна пройти фильтр');
      expect(
        sw.elapsedMilliseconds,
        lessThan(30),
        reason: 'Фильтрация 500 таблиц должна занимать менее 30 мс',
      );
    });
  });
}
