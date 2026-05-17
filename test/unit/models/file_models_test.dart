// test/unit/models/file_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gis_app/models/app_models.dart';
import '../../fixtures/test_fixtures.dart';

void main() {
  group('GisFile', () {
    group('sizeLabel', () {
      test('байты (< 1 KB)', () {
        final f = makeFile(sizeBytes: 512);
        expect(f.sizeLabel, equals('512B'));
      });

      test('килобайты (< 1 MB)', () {
        final f = makeFile(sizeBytes: 1536); // 1.5 KB
        expect(f.sizeLabel, equals('1.5KB'));
      });

      test('мегабайты (>= 1 MB)', () {
        final f = makeFile(sizeBytes: 10 * 1024 * 1024); // 10 MB
        expect(f.sizeLabel, equals('10.0MB'));
      });

      test('ровно 1 KB', () {
        final f = makeFile(sizeBytes: 1024);
        expect(f.sizeLabel, equals('1.0KB'));
      });

      test('ровно 1 MB', () {
        final f = makeFile(sizeBytes: 1024 * 1024);
        expect(f.sizeLabel, equals('1.0MB'));
      });

      test('0 байт', () {
        final f = makeFile(sizeBytes: 0);
        expect(f.sizeLabel, equals('0B'));
      });

      test('большой файл (184 MB)', () {
        final f = makeFile(sizeBytes: 184320000);
        expect(f.sizeLabel, contains('MB'));
      });
    });

    group('type properties', () {
      test('geotiff имеет иконку карты', () {
        expect(kTestFileGeotiff.type, equals(FileType.geotiff));
        expect(kTestFileGeotiff.type.label, equals('.tif'));
      });

      test('document имеет иконку документа', () {
        expect(kTestFileDocument.type, equals(FileType.document));
      });
    });

    group('поля', () {
      test('хранит id, name, type, sizeBytes, createdAt', () {
        expect(kTestFileGeotiff.id, equals('file_tif_1'));
        expect(kTestFileGeotiff.name, equals('test_ortho.tif'));
        expect(kTestFileGeotiff.sizeBytes, equals(10 * 1024 * 1024));
      });

      test('description по умолчанию пустая', () {
        final f = makeFile();
        expect(f.description, equals(''));
      });

      test('description хранится когда задана', () {
        expect(kTestFileDocument.description, equals('Отчёт'));
      });
    });
  });

  group('FileWithObject', () {
    test('хранит ссылки на файл и объект', () {
      final fw = makeFileWithObject(
        file: kTestFileDocument,
        objectId: 'obj_1',
        objectName: 'Поле №1',
      );
      expect(fw.file.id, equals('file_doc_1'));
      expect(fw.objectId, equals('obj_1'));
      expect(fw.objectName, equals('Поле №1'));
    });

    test('global file — objectId пустой', () {
      final fw = makeFileWithObject(objectId: '');
      expect(fw.objectId, isEmpty);
    });

    test('хранит иконку и цвет объекта', () {
      final fw = makeFileWithObject();
      expect(fw.objectIcon, isNotNull);
      expect(fw.objectColor, isNotNull);
    });
  });
}
