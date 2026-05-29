// test/load/repository_load_test.dart
// Нагрузочные тесты AppRepository.
//
// ВАЖНО: AppRepository содержит встроенные задержки (600ms для fetch,
// 250ms для write). Тесты НЕ замеряют время fetch-операций — они проверяют
// корректность работы при больших объёмах данных.
// Timing-тесты применяются только к операциям без async задержек
// (getSavedAccounts, getGlobalFiles, isLoginTaken и т.д.)

import 'package:flutter_test/flutter_test.dart';
import 'package:gis_app/repositories/app_repository.dart';
import 'package:gis_app/models/app_models.dart';
import '../helpers/prefs_helper.dart';
import '../fixtures/test_fixtures.dart';
import 'data_generator.dart';

void main() {
  late AppRepository repo;

  setUp(() async {
    final prefs = await createEmptyPrefs();
    repo = AppRepository(prefs);
  });

  group('Load Tests — Repository', () {
    group('GIS Objects', () {
      test('fetchObjects возвращает все seed-объекты', () async {
        final objects = await repo.fetchObjects();
        expect(objects, isNotEmpty);
        expect(objects.length, equals(7)); // 6 base + 1 AI demo object
      });

      test('addObject × 10 — объекты сохраняются', () async {
        final objects = generateObjects(10);
        for (final obj in objects) {
          await repo.addObject(obj);
        }
        final all = await repo.fetchObjects();
        expect(all.length, greaterThanOrEqualTo(10));
      });

      test('addObject × 10 — первый вставляется в начало', () async {
        final obj = makeGisObject(id: 'first_load_obj', name: 'Первый');
        await repo.addObject(obj);
        final all = await repo.fetchObjects();
        expect(all.first.id, equals('first_load_obj'));
      });

      test('20 объектов корректно добавляются', () async {
        final objects = generateObjects(20);
        for (final obj in objects) {
          await repo.addObject(obj);
        }
        final all = await repo.fetchObjects();
        // 7 seed + 20 added
        expect(all.length, equals(27));
      }, timeout: const Timeout(Duration(seconds: 30)));
    });

    group('Layers', () {
      test('fetchLayers для 5 объектов — все вернулись', () async {
        final objects = generateObjects(5);
        for (final obj in objects) {
          await repo.addObject(obj);
        }
        for (final obj in objects) {
          final layers = await repo.fetchLayers(obj.id);
          // объекты из generateObjects имеют 4 слоя
          expect(layers.length, equals(4));
        }
      });

      test('addLayer × 10 к одному объекту', () async {
        await repo.fetchLayers('obj_1'); // init cache
        final layers = generateLayers(10, prefix: 'obj_1_stress');
        for (final l in layers) {
          await repo.addLayer('obj_1', l);
        }
        final all = await repo.fetchLayers('obj_1');
        expect(all.length, greaterThanOrEqualTo(10));
      });

      test('toggleVisibility на 10 слоях поочерёдно', () async {
        await repo.fetchLayers('obj_1');
        final layers = await repo.fetchLayers('obj_1');
        for (int i = 0; i < layers.length; i++) {
          await repo.updateLayerVisibility('obj_1', layers[i].id, i.isEven);
        }
        final updated = await repo.fetchLayers('obj_1');
        expect(updated.length, equals(layers.length));
      });

      test('deleteLayer не удаляет лишние слои', () async {
        await repo.fetchLayers('obj_1');
        final before = (await repo.fetchLayers('obj_1')).length;
        final toDelete = (await repo.fetchLayers('obj_1')).first;
        await repo.deleteLayer('obj_1', toDelete.id);
        final after = await repo.fetchLayers('obj_1');
        expect(after.length, equals(before - 1));
      });
    });

    group('Files', () {
      test('addGlobalFile × 50 — синхронная операция', () {
        final files = generateFiles(50);
        final before = repo.getGlobalFiles().length;
        final ms = measureSyncMs(() {
          for (final f in files) {
            repo.addGlobalFile(f);
          }
        });
        expect(repo.getGlobalFiles().length, equals(before + 50));
        // Синхронная операция — должна быть быстрой
        expect(ms, lessThan(500), reason: 'addGlobalFile×50: ${ms}ms');
      });

      test('getGlobalFiles × 100 вызовов — стабильно', () {
        final ms = measureSyncMs(() {
          for (int i = 0; i < 100; i++) {
            repo.getGlobalFiles();
          }
        });
        expect(ms, lessThan(100));
      });

      test('deleteFiles × 100 файлов — синхронно и быстро', () async {
        final files = generateFiles(100);
        for (final f in files) {
          repo.addGlobalFile(f);
        }
        final idsToDelete = files.map((f) => f.id).toSet();
        final ms = measureSyncMs(() => repo.deleteFiles(idsToDelete));
        expect(ms, lessThan(200), reason: 'deleteFiles×100: ${ms}ms');
        final remaining = repo.getGlobalFiles();
        expect(remaining.any((f) => files.any((df) => df.id == f.id)), isFalse);
      });

      test('attachFileToObject × 30 к разным объектам — быстро', () async {
        final files = generateFiles(30);
        // Инициализируем кэш
        await repo.fetchFiles('obj_1');
        await repo.fetchFiles('obj_2');
        final ms = measureSyncMs(() {
          for (int i = 0; i < files.length; i++) {
            repo.attachFileToObject('obj_${(i % 2) + 1}', files[i]);
          }
        });
        expect(ms, lessThan(200), reason: 'attachFileToObject×30: ${ms}ms');
      });

      test('addFileToObject не дублирует файл', () async {
        final f = makeFile(id: 'unique_file', name: 'unique.tif', type: FileType.geotiff);
        await repo.fetchFiles('obj_1');
        repo.addFileToObject('obj_1', f);
        repo.addFileToObject('obj_1', f); // второй вызов
        final files = await repo.fetchFiles('obj_1');
        final count = files.where((x) => x.id == 'unique_file').length;
        expect(count, equals(1));
      });
    });

    group('Tables', () {
      test('createTable × 10 — все создаются', () async {
        final tables = generateTables(10, propsPerTable: 5);
        for (final t in tables) {
          await repo.createTable(t);
        }
        final all = await repo.fetchTables();
        // 4 seed + 10 created
        expect(all.length, equals(14));
      });

      test('таблица с 50 свойствами — корректный propertyCount', () async {
        final bigTable = generateTables(1, propsPerTable: 50).first;
        final result = await repo.createTable(bigTable);
        expect(result.propertyCount, equals(50));
      });

      test('updateTable обновляет все 4 seed-таблицы', () async {
        final tables = await repo.fetchTables();
        for (final t in tables) {
          await repo.updateTable(t.copyWith(name: '${t.name} UPDATED'));
        }
        final updated = await repo.fetchTables();
        expect(updated.every((t) => t.name.endsWith('UPDATED')), isTrue);
      });

      test('deleteTable × 4 — список пустеет', () async {
        final tables = await repo.fetchTables();
        for (final t in tables) {
          await repo.deleteTable(t.id);
        }
        final after = await repo.fetchTables();
        expect(after, isEmpty);
      });
    });

    group('Auth', () {
      test('register × 10 пользователей', () async {
        for (int i = 0; i < 10; i++) {
          await repo.register(
            login: 'load_user_$i', password: 'pass$i',
            firstName: 'User', lastName: '$i',
            organization: 'Org', email: 'user$i@test.ru',
          );
        }
        // Все 10 могут войти
        for (int i = 0; i < 10; i++) {
          final u = await repo.login('load_user_$i', 'pass$i');
          expect(u, isNotNull, reason: 'user $i не может войти');
        }
      });

      test('isLoginTaken — синхронная операция, быстро', () async {
        for (int i = 0; i < 10; i++) {
          await repo.register(
            login: 'lt_user_$i', password: 'p', firstName: 'A',
            lastName: 'B', organization: 'O', email: 'u$i@t.ru',
          );
        }
        final ms = measureSyncMs(() {
          for (int i = 0; i < 200; i++) {
            repo.isLoginTaken('lt_user_${i % 12}');
          }
        });
        expect(ms, lessThan(100), reason: 'isLoginTaken×200: ${ms}ms');
      });

      test('getSavedAccounts × 100 вызовов — быстро', () async {
        final user = await repo.login('admin', '123456');
        repo.saveAccount(user!);
        final ms = measureSyncMs(() {
          for (int i = 0; i < 100; i++) {
            repo.getSavedAccounts();
          }
        });
        expect(ms, lessThan(50));
      });
    });

    group('Sync operations — модели без delays', () {
      test('generateObjects(1000) — создаются быстро', () {
        final ms = measureSyncMs(() => generateObjects(1000));
        expect(ms, lessThan(500), reason: 'generateObjects(1000): ${ms}ms');
      });

      test('generateFiles(1000) — создаются быстро', () {
        final ms = measureSyncMs(() => generateFiles(1000));
        expect(ms, lessThan(200));
      });

      test('generateTables(100, propsPerTable: 20) — создаются быстро', () {
        final ms = measureSyncMs(() => generateTables(100, propsPerTable: 20));
        expect(ms, lessThan(200));
      });

      test('1000 GisFile.sizeLabel — быстро', () {
        final files = generateFiles(1000);
        final ms = measureSyncMs(() {
          for (final f in files) {
            final _ = f.sizeLabel;
          }
        });
        expect(ms, lessThan(50));
      });

      test('1000 MapDemoPoint.copyWith — быстро', () {
        final points = generatePoints(1000);
        final ms = measureSyncMs(() {
          for (final p in points) {
            p.copyWith(label: 'X', attributes: const {'k': 'v'});
          }
        });
        expect(ms, lessThan(50));
      });
    });
  });
}
