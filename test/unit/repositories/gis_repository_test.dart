// test/unit/repositories/gis_repository_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gis_app/repositories/app_repository.dart';
import 'package:gis_app/models/app_models.dart';
import '../../helpers/prefs_helper.dart';
import '../../fixtures/test_fixtures.dart';

void main() {
  late AppRepository repo;

  setUp(() async {
    final prefs = await createEmptyPrefs();
    repo = AppRepository(prefs);
  });

  group('AppRepository — GIS Objects', () {
    group('fetchCategories', () {
      test('возвращает непустой список категорий', () async {
        final cats = await repo.fetchCategories();
        expect(cats, isNotEmpty);
      });

      test('список неизменяемый', () async {
        final cats = await repo.fetchCategories();
        expect(() => (cats as dynamic).add(null), throwsA(anything));
      });
    });

    group('fetchObjects', () {
      test('возвращает seed-объекты', () async {
        final objects = await repo.fetchObjects();
        expect(objects, isNotEmpty);
        expect(objects.length, equals(7)); // 6 base + 1 AI demo object
      });

      test('список неизменяемый', () async {
        final objects = await repo.fetchObjects();
        expect(() => (objects as dynamic).add(null), throwsA(anything));
      });

      test('каждый объект имеет id', () async {
        final objects = await repo.fetchObjects();
        for (final obj in objects) {
          expect(obj.id, isNotEmpty);
        }
      });
    });

    group('addObject', () {
      test('добавляет объект в начало списка', () async {
        final newObj = makeGisObject(id: 'new_obj', name: 'Новый объект');
        await repo.addObject(newObj);
        final objects = await repo.fetchObjects();
        expect(objects.first.id, equals('new_obj'));
      });

      test('fetchObjects возвращает добавленный объект', () async {
        final newObj = makeGisObject(id: 'obj_unique_99', name: 'Уникальный');
        await repo.addObject(newObj);
        final objects = await repo.fetchObjects();
        expect(objects.any((o) => o.id == 'obj_unique_99'), isTrue);
      });

      test('количество объектов увеличивается', () async {
        final before = (await repo.fetchObjects()).length;
        await repo.addObject(makeGisObject(id: 'extra_obj'));
        final after = (await repo.fetchObjects()).length;
        expect(after, equals(before + 1));
      });
    });

    group('fetchLayers', () {
      test('возвращает слои первого объекта', () async {
        final layers = await repo.fetchLayers('obj_1');
        expect(layers, isNotEmpty);
      });

      test('использует кэш при повторном вызове', () async {
        final layers1 = await repo.fetchLayers('obj_1');
        final layers2 = await repo.fetchLayers('obj_1');
        expect(layers2.length, equals(layers1.length));
      });

      test('возвращает пустой список для несуществующего objectId', () async {
        final layers = await repo.fetchLayers('nonexistent_obj');
        expect(layers, isEmpty);
      });

      test('разные объекты имеют независимые слои', () async {
        final l1 = await repo.fetchLayers('obj_1');
        final l2 = await repo.fetchLayers('obj_2');
        // Слои изолированы: ID разные (с разными префиксами)
        expect(l1.first.id, startsWith('obj_1_'));
        expect(l2.first.id, startsWith('obj_2_'));
      });
    });

    group('updateLayerVisibility', () {
      test('меняет видимость слоя', () async {
        final layers = await repo.fetchLayers('obj_1');
        final layer = layers.first;
        final wasVisible = layer.isVisible;

        await repo.updateLayerVisibility('obj_1', layer.id, !wasVisible);
        final updated = await repo.fetchLayers('obj_1');
        final changedLayer = updated.firstWhere((l) => l.id == layer.id);
        expect(changedLayer.isVisible, equals(!wasVisible));
      });

      test('несуществующий objectId — не падает', () async {
        await expectLater(
          repo.updateLayerVisibility('no_obj', 'no_layer', true),
          completes,
        );
      });

      test('несуществующий layerId — не меняет слои', () async {
        final before = await repo.fetchLayers('obj_1');
        await repo.updateLayerVisibility('obj_1', 'no_layer', false);
        final after = await repo.fetchLayers('obj_1');
        expect(after.length, equals(before.length));
      });
    });

    group('deleteLayer', () {
      test('удаляет слой по id', () async {
        final layers = await repo.fetchLayers('obj_1');
        final toDelete = layers.first;
        final beforeCount = layers.length;

        await repo.deleteLayer('obj_1', toDelete.id);
        final after = await repo.fetchLayers('obj_1');
        expect(after.length, equals(beforeCount - 1));
        expect(after.any((l) => l.id == toDelete.id), isFalse);
      });

      test('удаление несуществующего слоя — не падает', () async {
        await repo.fetchLayers('obj_1'); // init cache
        await expectLater(
          repo.deleteLayer('obj_1', 'no_such_layer'),
          completes,
        );
      });
    });

    group('addLayer', () {
      test('добавляет слой к объекту', () async {
        await repo.fetchLayers('obj_1'); // init cache
        final before = (await repo.fetchLayers('obj_1')).length;

        final newLayer = makeLayer(id: 'new_layer_99', name: 'Новый слой');
        await repo.addLayer('obj_1', newLayer);

        final after = await repo.fetchLayers('obj_1');
        expect(after.length, equals(before + 1));
        expect(after.any((l) => l.id == 'new_layer_99'), isTrue);
      });

      test('добавляет слой даже без предварительного fetchLayers', () async {
        final newLayer = makeLayer(id: 'auto_init_layer', name: 'Auto');
        await repo.addLayer('obj_1', newLayer);
        final layers = await repo.fetchLayers('obj_1');
        expect(layers.any((l) => l.id == 'auto_init_layer'), isTrue);
      });
    });

    group('updateObject', () {
      test('обновляет название объекта', () async {
        final objects = await repo.fetchObjects();
        final original = objects.firstWhere((o) => o.id == 'obj_1');
        final updated = GisObject(
          id: original.id, name: 'Обновлённое название',
          description: original.description, category: original.category,
          layers: original.layers, updatedAt: DateTime.now(),
          icon: original.icon,
        );
        await repo.updateObject(updated);
        final afterUpdate = await repo.fetchObjects();
        final found = afterUpdate.firstWhere((o) => o.id == 'obj_1');
        expect(found.name, equals('Обновлённое название'));
      });

      test('обновляет описание объекта', () async {
        final objects = await repo.fetchObjects();
        final original = objects.firstWhere((o) => o.id == 'obj_1');
        final updated = GisObject(
          id: original.id, name: original.name,
          description: 'Новое описание', category: original.category,
          layers: original.layers, updatedAt: DateTime.now(),
          icon: original.icon,
        );
        await repo.updateObject(updated);
        final afterUpdate = await repo.fetchObjects();
        expect(afterUpdate.firstWhere((o) => o.id == 'obj_1').description,
            equals('Новое описание'));
      });

      test('не изменяет другие объекты', () async {
        final before = await repo.fetchObjects();
        final obj2Before = before.firstWhere((o) => o.id == 'obj_2');
        final obj1 = before.firstWhere((o) => o.id == 'obj_1');

        await repo.updateObject(GisObject(
          id: obj1.id, name: 'Изменён', description: obj1.description,
          category: obj1.category, layers: obj1.layers,
          updatedAt: DateTime.now(), icon: obj1.icon,
        ));

        final after = await repo.fetchObjects();
        final obj2After = after.firstWhere((o) => o.id == 'obj_2');
        expect(obj2After.name, equals(obj2Before.name));
      });

      test('несуществующий id — не падает', () async {
        final phantom = makeGisObject(id: 'no_such_id', name: 'Phantom');
        await expectLater(repo.updateObject(phantom), completes);
      });

      test('количество объектов не меняется', () async {
        final before = (await repo.fetchObjects()).length;
        final obj = (await repo.fetchObjects()).first;
        await repo.updateObject(GisObject(
          id: obj.id, name: 'x', description: obj.description,
          category: obj.category, layers: obj.layers,
          updatedAt: DateTime.now(), icon: obj.icon,
        ));
        final after = (await repo.fetchObjects()).length;
        expect(after, equals(before));
      });
    });

    group('deleteObject', () {
      test('удаляет объект по id', () async {
        final before = await repo.fetchObjects();
        final toDelete = before.firstWhere((o) => o.id == 'obj_1');
        await repo.deleteObject(toDelete.id);
        final after = await repo.fetchObjects();
        expect(after.any((o) => o.id == 'obj_1'), isFalse);
      });

      test('уменьшает количество объектов на 1', () async {
        final before = (await repo.fetchObjects()).length;
        await repo.deleteObject('obj_1');
        final after = (await repo.fetchObjects()).length;
        expect(after, equals(before - 1));
      });

      test('удаление несуществующего id — не падает', () async {
        await expectLater(repo.deleteObject('no_such_id'), completes);
      });

      test('не удаляет другие объекты', () async {
        await repo.deleteObject('obj_1');
        final after = await repo.fetchObjects();
        expect(after.any((o) => o.id == 'obj_2'), isTrue);
        expect(after.any((o) => o.id == 'obj_3'), isTrue);
      });

      test('удаление всех объектов одного за другим', () async {
        final all = await repo.fetchObjects();
        for (final obj in all) {
          await repo.deleteObject(obj.id);
        }
        final after = await repo.fetchObjects();
        expect(after, isEmpty);
      });
    });
  });
}
