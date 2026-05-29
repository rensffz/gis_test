// test/unit/models/gis_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gis_app/models/app_models.dart';
import '../../fixtures/test_fixtures.dart';

void main() {
  group('GisLayer', () {
    group('copyWith', () {
      test('copyWith(isVisible: false) меняет видимость', () {
        final hidden = kTestLayerArea.copyWith(isVisible: false);
        expect(hidden.isVisible, isFalse);
        expect(hidden.id, equals(kTestLayerArea.id));
        expect(hidden.name, equals(kTestLayerArea.name));
        expect(hidden.type, equals(kTestLayerArea.type));
      });

      test('copyWith(isVisible: true) включает видимость', () {
        final hidden = kTestLayerOrtho; // isVisible: false
        final visible = hidden.copyWith(isVisible: true);
        expect(visible.isVisible, isTrue);
      });

      test('copyWith без аргументов сохраняет все поля', () {
        final copy = kTestLayerPoints.copyWith();
        expect(copy.id, equals(kTestLayerPoints.id));
        expect(copy.tableId, equals(kTestLayerPoints.tableId));
        expect(copy.objectsCount, equals(kTestLayerPoints.objectsCount));
      });
    });

    group('type properties', () {
      test('points layer ссылается на таблицу', () {
        expect(kTestLayerPoints.tableId, equals('tbl_1'));
        expect(kTestLayerPoints.type.supportsTable, isTrue);
      });

      test('ortho layer ссылается на файл', () {
        expect(kTestLayerOrtho.fileId, equals('file_1'));
        expect(kTestLayerOrtho.type.requiresFile, isTrue);
      });

      test('area layer без ссылок', () {
        expect(kTestLayerArea.tableId, isNull);
        expect(kTestLayerArea.fileId, isNull);
      });
    });
  });

  group('GisObject', () {
    test('layerCount равен числу слоёв', () {
      final obj = makeGisObject(layers: [kTestLayerArea, kTestLayerPoints]);
      expect(obj.layerCount, equals(2));
    });

    test('totalObjects суммирует objectsCount всех слоёв', () {
      final obj = makeGisObject(layers: [
        makeLayer(id: 'l1', objectsCount: 5),
        makeLayer(id: 'l2', objectsCount: 10),
        makeLayer(id: 'l3', objectsCount: 3),
      ]);
      expect(obj.totalObjects, equals(18));
    });

    test('totalObjects = 0 для объекта без слоёв', () {
      final obj = makeGisObject(layers: []);
      expect(obj.totalObjects, equals(0));
    });

    test('layerCount = 0 для объекта без слоёв', () {
      final obj = makeGisObject(layers: []);
      expect(obj.layerCount, equals(0));
    });

    test('хранит ссылку на категорию', () {
      final obj = makeGisObject(category: kTestCategory);
      expect(obj.category.id, equals('cat_test'));
    });
  });

  group('MapDemoPoint', () {
    test('хранит координаты в допустимом диапазоне WGS84', () {
      expect(kTestPoint1.lat, inInclusiveRange(-90.0, 90.0));
      expect(kTestPoint1.lng, inInclusiveRange(-180.0, 180.0));
    });

    test('хранит реальные координаты демо-области', () {
      expect(kTestPoint1.lat, closeTo(55.468, 0.001));
      expect(kTestPoint1.lng, closeTo(37.498, 0.001));
    });

    test('copyWith обновляет label', () {
      final updated = kTestPoint1.copyWith(label: 'P-99');
      expect(updated.label, equals('P-99'));
      expect(updated.lat, equals(kTestPoint1.lat));
      expect(updated.lng, equals(kTestPoint1.lng));
      expect(updated.color, equals(kTestPoint1.color));
    });

    test('copyWith обновляет attributes', () {
      final updated = kTestPoint1.copyWith(attributes: {'key': 'val'});
      expect(updated.attributes['key'], equals('val'));
      expect(updated.label, equals(kTestPoint1.label));
    });

    test('copyWith без аргументов сохраняет данные', () {
      final copy = kTestPoint2.copyWith();
      expect(copy.attributes, equals(kTestPoint2.attributes));
    });

    test('attributes по умолчанию пустые', () {
      expect(kTestPoint1.attributes, isEmpty);
    });

    test('attributes хранятся корректно', () {
      expect(kTestPoint2.attributes['prop_str_1'], equals('значение'));
      expect(kTestPoint2.attributes['prop_int_1'], equals('42'));
    });

    group('edge cases', () {
      test('южное полушарие — отрицательная широта', () {
        final p = makePoint(lat: -33.9, lng: 18.4); // Cape Town
        expect(p.lat, equals(-33.9));
        expect(p.lng, equals(18.4));
      });

      test('западное полушарие — отрицательная долгота', () {
        final p = makePoint(lat: 40.7, lng: -74.0); // New York
        expect(p.lat, equals(40.7));
        expect(p.lng, equals(-74.0));
      });

      test('пустой label допустим', () {
        final p = makePoint(label: '');
        expect(p.label, equals(''));
      });
    });
  });
}
