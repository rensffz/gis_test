// test/unit/models/table_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gis_app/models/app_models.dart';
import '../../fixtures/test_fixtures.dart';

void main() {
  group('AttributeProperty', () {
    group('copyWith', () {
      test('обновляет name', () {
        final updated = kTestPropString.copyWith(name: 'Новое название');
        expect(updated.name, equals('Новое название'));
        expect(updated.id, equals(kTestPropString.id));
        expect(updated.dataType, equals(kTestPropString.dataType));
      });

      test('обновляет dataType', () {
        final updated = kTestPropString.copyWith(dataType: DataType.integer);
        expect(updated.dataType, equals(DataType.integer));
      });

      test('обновляет measurementUnit', () {
        final updated = kTestPropString.copyWith(measurementUnit: 'кг');
        expect(updated.measurementUnit, equals('кг'));
      });

      test('обновляет description', () {
        final updated = kTestPropString.copyWith(description: 'Новое описание');
        expect(updated.description, equals('Новое описание'));
      });

      test('без аргументов сохраняет все поля', () {
        final copy = kTestPropInt.copyWith();
        expect(copy.id, equals(kTestPropInt.id));
        expect(copy.name, equals(kTestPropInt.name));
        expect(copy.dataType, equals(kTestPropInt.dataType));
        expect(copy.measurementUnit, equals(kTestPropInt.measurementUnit));
      });
    });

    group('dataType defaults', () {
      test('по умолчанию тип string', () {
        const prop = AttributeProperty(
          id: 'p', name: 'name', description: '', measurementUnit: '',
        );
        expect(prop.dataType, equals(DataType.string));
      });
    });
  });

  group('AttributeTable', () {
    group('propertyCount', () {
      test('возвращает количество свойств', () {
        final table = makeTable(properties: [kTestPropString, kTestPropInt, kTestPropDouble]);
        expect(table.propertyCount, equals(3));
      });

      test('0 для пустой таблицы', () {
        final table = makeTable(properties: []);
        expect(table.propertyCount, equals(0));
      });

      test('1 для одного свойства', () {
        final table = makeTable(properties: [kTestPropString]);
        expect(table.propertyCount, equals(1));
      });
    });

    group('copyWith', () {
      test('обновляет name', () {
        final table = makeTable();
        final updated = table.copyWith(name: 'Новое имя');
        expect(updated.name, equals('Новое имя'));
        expect(updated.id, equals(table.id));
      });

      test('обновляет properties', () {
        final table = makeTable(properties: [kTestPropString]);
        final updated = table.copyWith(properties: [kTestPropString, kTestPropInt]);
        expect(updated.propertyCount, equals(2));
      });

      test('обновляет updatedAt', () {
        final table = makeTable();
        final newDate = DateTime(2025, 1, 1);
        final updated = table.copyWith(updatedAt: newDate);
        expect(updated.updatedAt, equals(newDate));
      });

      test('обновляет description', () {
        final table = makeTable(description: 'Старое');
        final updated = table.copyWith(description: 'Новое');
        expect(updated.description, equals('Новое'));
      });

      test('без аргументов сохраняет все поля', () {
        final table = makeTable();
        final copy = table.copyWith();
        expect(copy.id, equals(table.id));
        expect(copy.name, equals(table.name));
        expect(copy.propertyCount, equals(table.propertyCount));
      });
    });

    group('properties', () {
      test('список свойств доступен', () {
        final table = makeTable(properties: [kTestPropString, kTestPropInt]);
        expect(table.properties[0].id, equals('prop_str_1'));
        expect(table.properties[1].id, equals('prop_int_1'));
      });

      test('поддерживает разные типы данных', () {
        final table = makeTable(properties: [
          kTestPropString,  // string
          kTestPropInt,     // integer
          kTestPropDouble,  // double_
        ]);
        final types = table.properties.map((p) => p.dataType).toList();
        expect(types, containsAll([DataType.string, DataType.integer, DataType.double_]));
      });
    });
  });
}
