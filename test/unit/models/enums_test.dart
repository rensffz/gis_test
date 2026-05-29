// test/unit/models/enums_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gis_app/models/app_models.dart';

void main() {
  group('LayerType', () {
    group('label', () {
      test('area → AREA', () => expect(LayerType.area.label, equals('AREA')));
      test('points → POINTS', () => expect(LayerType.points.label, equals('POINTS')));
      test('orthophoto → ORTHOPHOTO', () => expect(LayerType.orthophoto.label, equals('ORTHOPHOTO')));
      test('segmentation → AI SEG', () => expect(LayerType.segmentation.label, equals('AI SEG')));
    });

    group('icon', () {
      test('каждый тип имеет иконку', () {
        for (final t in LayerType.values) {
          expect(t.icon, isNotNull, reason: 'Иконка для $t не задана');
        }
      });
    });

    group('color', () {
      test('каждый тип имеет цвет', () {
        for (final t in LayerType.values) {
          expect(t.color, isNotNull, reason: 'Цвет для $t не задан');
        }
      });
    });

    group('supportsTable', () {
      test('только points поддерживает таблицу', () {
        expect(LayerType.points.supportsTable, isTrue);
        expect(LayerType.area.supportsTable, isFalse);
        expect(LayerType.orthophoto.supportsTable, isFalse);
        expect(LayerType.segmentation.supportsTable, isFalse);
      });
    });

    group('requiresFile', () {
      test('только orthophoto требует файл', () {
        expect(LayerType.orthophoto.requiresFile, isTrue);
        expect(LayerType.area.requiresFile, isFalse);
        expect(LayerType.points.requiresFile, isFalse);
        expect(LayerType.segmentation.requiresFile, isFalse);
      });
    });
  });

  group('FileType', () {
    group('label', () {
      test('все типы имеют label', () {
        for (final t in FileType.values) {
          expect(t.label, isNotEmpty, reason: 'Label для $t не задан');
        }
      });
      test('geotiff → .tif', () => expect(FileType.geotiff.label, equals('.tif')));
      test('other → FILE', () => expect(FileType.other.label, equals('FILE')));
    });

    group('icon', () {
      test('каждый тип имеет иконку', () {
        for (final t in FileType.values) {
          expect(t.icon, isNotNull, reason: 'Иконка для $t не задана');
        }
      });
    });

    group('color', () {
      test('каждый тип имеет цвет', () {
        for (final t in FileType.values) {
          expect(t.color, isNotNull, reason: 'Цвет для $t не задан');
        }
      });
    });
  });

  group('DataType', () {
    group('label', () {
      test('integer → INTEGER', () => expect(DataType.integer.label, equals('INTEGER')));
      test('double_ → DOUBLE', () => expect(DataType.double_.label, equals('DOUBLE')));
      test('string → STRING', () => expect(DataType.string.label, equals('STRING')));
    });

    group('icon', () {
      test('каждый тип имеет иконку', () {
        for (final t in DataType.values) {
          expect(t.icon, isNotNull, reason: 'Иконка для $t не задана');
        }
      });
    });
  });

  group('kAllowedFileTypes', () {
    test('содержит geotiff и other', () {
      expect(kAllowedFileTypes, contains(FileType.geotiff));
      expect(kAllowedFileTypes, contains(FileType.other));
    });

    test('не содержит image, video, document, pointcloud', () {
      expect(kAllowedFileTypes, isNot(contains(FileType.image)));
      expect(kAllowedFileTypes, isNot(contains(FileType.video)));
      expect(kAllowedFileTypes, isNot(contains(FileType.document)));
      expect(kAllowedFileTypes, isNot(contains(FileType.pointcloud)));
    });
  });
}
