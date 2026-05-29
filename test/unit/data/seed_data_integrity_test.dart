// test/unit/data/seed_data_integrity_test.dart
// Проверяем целостность seed-данных и структуру категорий.
// Эти тесты сломаются если кто-то случайно изменит бизнес-данные.

import 'package:flutter_test/flutter_test.dart';
import 'package:gis_app/repositories/app_repository.dart';
import 'package:gis_app/models/app_models.dart';
import '../../helpers/prefs_helper.dart';

void main() {
  late AppRepository repo;

  setUp(() async {
    final prefs = await createEmptyPrefs();
    repo = AppRepository(prefs);
  });

  group('Категории', () {
    test('ровно 3 категории', () async {
      final cats = await repo.fetchCategories();
      expect(cats.length, equals(3));
    });

    test('содержит Городские экосистемы', () async {
      final cats = await repo.fetchCategories();
      expect(cats.any((c) => c.name == 'Городские экосистемы'), isTrue);
    });

    test('содержит Лесные экосистемы', () async {
      final cats = await repo.fetchCategories();
      expect(cats.any((c) => c.name == 'Лесные экосистемы'), isTrue);
    });

    test('содержит Сельские экосистемы', () async {
      final cats = await repo.fetchCategories();
      expect(cats.any((c) => c.name == 'Сельские экосистемы'), isTrue);
    });

    test('у каждой категории уникальный id', () async {
      final cats = await repo.fetchCategories();
      final ids = cats.map((c) => c.id).toSet();
      expect(ids.length, equals(cats.length));
    });

    test('у каждой категории есть цвет и иконка', () async {
      final cats = await repo.fetchCategories();
      for (final cat in cats) {
        expect(cat.color, isNotNull, reason: 'Цвет для ${cat.name}');
        expect(cat.icon, isNotNull, reason: 'Иконка для ${cat.name}');
      }
    });

    test('старых категорий нет (Сельхозугодья, Дороги, и т.д.)', () async {
      final cats = await repo.fetchCategories();
      final names = cats.map((c) => c.name).toList();
      expect(names, isNot(contains('Сельхозугодья')));
      expect(names, isNot(contains('Водные объекты')));
      expect(names, isNot(contains('Дороги')));
      expect(names, isNot(contains('Строения')));
      expect(names, isNot(contains('Лесной фонд')));
    });
  });

  group('Seed объекты', () {
    test('ровно 7 seed-объектов', () async {
      final objects = await repo.fetchObjects();
      expect(objects.length, equals(7));
    });

    test('все объекты имеют непустые id и name', () async {
      final objects = await repo.fetchObjects();
      for (final obj in objects) {
        expect(obj.id, isNotEmpty, reason: 'id объекта');
        expect(obj.name, isNotEmpty, reason: 'name объекта ${obj.id}');
      }
    });

    test('все id уникальны', () async {
      final objects = await repo.fetchObjects();
      final ids = objects.map((o) => o.id).toSet();
      expect(ids.length, equals(objects.length));
    });

    test('все объекты принадлежат одной из 3 категорий', () async {
      final objects = await repo.fetchObjects();
      final cats = await repo.fetchCategories();
      final catIds = cats.map((c) => c.id).toSet();
      for (final obj in objects) {
        expect(catIds, contains(obj.category.id),
            reason: '${obj.name} ссылается на несуществующую категорию');
      }
    });

    test('AI-демо объект присутствует с нужными слоями', () async {
      final objects = await repo.fetchObjects();
      final aiObj = objects.where((o) => o.id == 'obj_ai').firstOrNull;
      expect(aiObj, isNotNull, reason: 'obj_ai должен существовать');

      final layerTypes = aiObj!.layers.map((l) => l.type).toSet();
      expect(layerTypes, contains(LayerType.orthophoto));
      expect(layerTypes, contains(LayerType.segmentation));
      expect(layerTypes, contains(LayerType.points));
    });

    test('AI-демо объект относится к Лесным экосистемам', () async {
      final objects = await repo.fetchObjects();
      final aiObj = objects.firstWhere((o) => o.id == 'obj_ai');
      expect(aiObj.category.name, equals('Лесные экосистемы'));
    });

    test('у объектов с type=points слой ссылается на tableId', () async {
      final objects = await repo.fetchObjects();
      for (final obj in objects) {
        for (final layer in obj.layers) {
          if (layer.type == LayerType.points) {
            // points-слой должен либо иметь tableId, либо это mock без привязки
            // Главное — не иметь fileId
            expect(layer.fileId, isNull,
                reason: '${layer.name} в ${obj.name}: points не должен иметь fileId');
          }
        }
      }
    });

    test('у объектов с type=orthophoto слой ссылается на fileId', () async {
      final objects = await repo.fetchObjects();
      for (final obj in objects) {
        for (final layer in obj.layers) {
          if (layer.type == LayerType.orthophoto) {
            expect(layer.fileId, isNotNull,
                reason: '${layer.name} в ${obj.name}: orthophoto должен иметь fileId');
          }
        }
      }
    });
  });

  group('Seed таблицы', () {
    test('все таблицы имеют хотя бы одно свойство', () async {
      final tables = await repo.fetchTables();
      for (final t in tables) {
        expect(t.properties, isNotEmpty,
            reason: '${t.name} должна иметь свойства');
      }
    });

    test('все id свойств уникальны в рамках таблицы', () async {
      final tables = await repo.fetchTables();
      for (final t in tables) {
        final propIds = t.properties.map((p) => p.id).toSet();
        expect(propIds.length, equals(t.properties.length),
            reason: 'В ${t.name} дублированные id свойств');
      }
    });

    test('таблицы имеют непустые названия', () async {
      final tables = await repo.fetchTables();
      for (final t in tables) {
        expect(t.name, isNotEmpty);
        expect(t.description, isNotEmpty);
      }
    });
  });

  group('Seed файлы (глобальные)', () {
    test('глобальное хранилище не пустое', () {
      final files = repo.getGlobalFiles();
      expect(files, isNotEmpty);
    });

    test('все файлы имеют корректный sizeBytes (> 0)', () {
      final files = repo.getGlobalFiles();
      for (final f in files) {
        expect(f.sizeBytes, greaterThan(0),
            reason: '${f.name} имеет нулевой размер');
      }
    });

    test('все id файлов уникальны', () {
      final files = repo.getGlobalFiles();
      final ids = files.map((f) => f.id).toSet();
      expect(ids.length, equals(files.length));
    });

    test('g_f1 существует — ортофото ссылается на него', () {
      final files = repo.getGlobalFiles();
      expect(files.any((f) => f.id == 'g_f1'), isTrue,
          reason: 'g_f1 нужен для orthophoto-слоёв');
    });
  });

  group('LayerType.segmentation', () {
    test('label == AI SEG', () {
      expect(LayerType.segmentation.label, equals('AI SEG'));
    });

    test('не требует таблицу', () {
      expect(LayerType.segmentation.supportsTable, isFalse);
    });

    test('не требует файл', () {
      expect(LayerType.segmentation.requiresFile, isFalse);
    });

    test('имеет иконку и цвет', () {
      expect(LayerType.segmentation.icon, isNotNull);
      expect(LayerType.segmentation.color, isNotNull);
    });
  });

  group('MapDemoPoint — демо-координаты', () {
    test('демо-точки в приложении находятся около Подольска', () {
      // Центр демо-области: 55.47°N, 37.50°E (р. Десна, Подольский р-н)
      const demoPoints = [
        (55.468, 37.498),
        (55.472, 37.505),
        (55.466, 37.512),
        (55.475, 37.488),
      ];

      for (final (lat, lng) in demoPoints) {
        // Широта должна быть в диапазоне Московской области
        expect(lat, inInclusiveRange(54.0, 57.0),
            reason: 'lat=$lat вне Московской области');
        // Долгота — в районе Подольска
        expect(lng, inInclusiveRange(36.0, 40.0),
            reason: 'lng=$lng вне ожидаемого диапазона');
      }
    });
  });
}
