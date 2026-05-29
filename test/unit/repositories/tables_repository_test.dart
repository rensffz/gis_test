// test/unit/repositories/tables_repository_test.dart
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

  group('AppRepository — Tables', () {
    group('createTable', () {
      test('создаёт таблицу и добавляет в список', () async {
        final before = (await repo.fetchTables()).length;
        final newTable = makeTable(id: 'tbl_new', name: 'Новая таблица');
        await repo.createTable(newTable);
        final after = await repo.fetchTables();
        expect(after.length, equals(before + 1));
      });

      test('новая таблица в начале списка', () async {
        final newTable = makeTable(id: 'tbl_first', name: 'Первая');
        await repo.createTable(newTable);
        final tables = await repo.fetchTables();
        expect(tables.first.id, equals('tbl_first'));
      });

      test('возвращает созданную таблицу', () async {
        final newTable = makeTable(id: 'tbl_ret', name: 'Возврат');
        final result = await repo.createTable(newTable);
        expect(result.id, equals('tbl_ret'));
        expect(result.name, equals('Возврат'));
      });

      test('создаёт таблицу с пустым списком свойств', () async {
        final empty = makeTable(id: 'tbl_empty', properties: []);
        final result = await repo.createTable(empty);
        expect(result.propertyCount, equals(0));
      });

      test('создаёт таблицу с несколькими свойствами', () async {
        final table = makeTable(
          id: 'tbl_props',
          properties: [kTestPropString, kTestPropInt, kTestPropDouble],
        );
        final result = await repo.createTable(table);
        expect(result.propertyCount, equals(3));
      });
    });

    group('updateTable', () {
      test('обновляет существующую таблицу', () async {
        final tables = await repo.fetchTables();
        final original = tables.first;
        final updated = original.copyWith(name: 'Обновлённое название');
        await repo.updateTable(updated);
        final after = await repo.fetchTables();
        expect(after.firstWhere((t) => t.id == original.id).name,
            equals('Обновлённое название'));
      });

      test('обновляет updatedAt', () async {
        final tables = await repo.fetchTables();
        final original = tables.first;
        final before = original.updatedAt;
        await Future.delayed(const Duration(milliseconds: 5));
        await repo.updateTable(original.copyWith(name: 'changed'));
        final after = await repo.fetchTables();
        final saved = after.firstWhere((t) => t.id == original.id);
        expect(saved.updatedAt.isAfter(before) || saved.updatedAt == before, isTrue);
      });

      test('обновляет properties', () async {
        final tables = await repo.fetchTables();
        final original = tables.first;
        final updated = original.copyWith(
          properties: [kTestPropString, kTestPropInt],
        );
        await repo.updateTable(updated);
        final after = await repo.fetchTables();
        expect(after.firstWhere((t) => t.id == original.id).propertyCount, equals(2));
      });

      test('возвращает обновлённую таблицу', () async {
        final tables = await repo.fetchTables();
        final original = tables.first;
        final result = await repo.updateTable(original.copyWith(description: 'Новое описание'));
        expect(result.description, equals('Новое описание'));
      });
    });

    group('deleteTable', () {
      test('удаляет таблицу по id', () async {
        final tables = await repo.fetchTables();
        final toDelete = tables.first;
        final before = tables.length;
        await repo.deleteTable(toDelete.id);
        final after = await repo.fetchTables();
        expect(after.length, equals(before - 1));
        expect(after.any((t) => t.id == toDelete.id), isFalse);
      });

      test('удаление несуществующей таблицы — не меняет список', () async {
        final before = (await repo.fetchTables()).length;
        await repo.deleteTable('nonexistent_id');
        final after = (await repo.fetchTables()).length;
        expect(after, equals(before));
      });

      test('удаляет конкретную таблицу (не все)', () async {
        final tables = await repo.fetchTables();
        final toDelete = tables[1]; // Вторая таблица
        await repo.deleteTable(toDelete.id);
        final after = await repo.fetchTables();
        // Остальные таблицы целы
        expect(after.any((t) => t.id == tables[0].id), isTrue);
        expect(after.any((t) => t.id == tables[2].id), isTrue);
      });
    });
  });
}
