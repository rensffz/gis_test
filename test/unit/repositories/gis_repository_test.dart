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
        expect(objects.length, equals(6)); // seed data contains 6 objects
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
  });
}
