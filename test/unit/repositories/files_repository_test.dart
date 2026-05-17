// test/unit/repositories/files_repository_test.dart
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

  group('AppRepository — Files', () {
    group('fetchFiles (per-object)', () {
      test('возвращает файлы для объекта', () async {
        final files = await repo.fetchFiles('obj_1');
        expect(files, isNotEmpty);
      });

      test('кэширует результат', () async {
        final f1 = await repo.fetchFiles('obj_1');
        final f2 = await repo.fetchFiles('obj_1');
        expect(f2.length, equals(f1.length));
      });

      test('разные объекты имеют независимые наборы файлов', () async {
        final f1 = await repo.fetchFiles('obj_1');
        final f2 = await repo.fetchFiles('obj_2');
        expect(f1.first.id, isNot(equals(f2.first.id)));
      });
    });

    group('getGlobalFiles', () {
      test('возвращает seed-файлы глобального хранилища', () {
        final files = repo.getGlobalFiles();
        expect(files, isNotEmpty);
      });

      test('список неизменяемый', () {
        final files = repo.getGlobalFiles();
        expect(() => (files as dynamic).add(null), throwsA(anything));
      });
    });

    group('addGlobalFile', () {
      test('добавляет файл в глобальное хранилище', () {
        final before = repo.getGlobalFiles().length;
        final f = makeFile(id: 'new_global_f', name: 'new.tif', type: FileType.geotiff);
        repo.addGlobalFile(f);
        expect(repo.getGlobalFiles().length, equals(before + 1));
      });

      test('возвращает FileWithObject с пустым objectId', () {
        final f = makeFile(id: 'global_test');
        final fw = repo.addGlobalFile(f);
        expect(fw.objectId, isEmpty);
        expect(fw.file.id, equals('global_test'));
      });
    });

    group('addFileToObject', () {
      test('добавляет файл к объекту', () async {
        final before = (await repo.fetchFiles('obj_1')).length;
        final f = makeFile(id: 'new_obj_file', name: 'extra.file');
        repo.addFileToObject('obj_1', f);
        final after = await repo.fetchFiles('obj_1');
        expect(after.length, equals(before + 1));
      });

      test('не дублирует уже существующий файл', () async {
        final files = await repo.fetchFiles('obj_1');
        final existing = files.first;
        final before = files.length;
        repo.addFileToObject('obj_1', existing);
        final after = await repo.fetchFiles('obj_1');
        expect(after.length, equals(before));
      });

      test('возвращает FileWithObject с корректным objectId', () async {
        final f = makeFile(id: 'obj_attached_file');
        final fw = repo.addFileToObject('obj_1', f);
        expect(fw.objectId, equals('obj_1'));
      });
    });

    group('attachFileToObject', () {
      test('прикрепляет глобальный файл к объекту', () async {
        final globalFiles = repo.getGlobalFiles();
        final toAttach = globalFiles.first;
        await repo.fetchFiles('obj_1'); // init cache

        repo.attachFileToObject('obj_1', toAttach);
        final objFiles = await repo.fetchFiles('obj_1');
        expect(objFiles.any((f) => f.id == toAttach.id), isTrue);
      });

      test('не дублирует уже прикреплённый файл', () async {
        final toAttach = repo.getGlobalFiles().first;
        await repo.fetchFiles('obj_1');
        repo.attachFileToObject('obj_1', toAttach);
        repo.attachFileToObject('obj_1', toAttach);
        final files = await repo.fetchFiles('obj_1');
        final count = files.where((f) => f.id == toAttach.id).length;
        expect(count, equals(1));
      });
    });

    group('fetchAllFiles', () {
      test('содержит глобальные и объектные файлы', () async {
        final all = await repo.fetchAllFiles();
        expect(all, isNotEmpty);
        // Глобальные файлы (objectId == '')
        final global = all.where((fw) => fw.objectId.isEmpty).toList();
        expect(global, isNotEmpty);
        // Объектные файлы (objectId != '')
        final bound = all.where((fw) => fw.objectId.isNotEmpty).toList();
        expect(bound, isNotEmpty);
      });

      test('глобальные файлы идут первыми', () async {
        final all = await repo.fetchAllFiles();
        expect(all.first.objectId, isEmpty);
      });
    });

    group('deleteFiles', () {
      test('удаляет файлы из глобального хранилища', () async {
        final globalFiles = repo.getGlobalFiles();
        final toDelete = globalFiles.first;
        repo.deleteFiles({toDelete.id});
        expect(repo.getGlobalFiles().any((f) => f.id == toDelete.id), isFalse);
      });

      test('удаляет файлы из объектного хранилища', () async {
        final files = await repo.fetchFiles('obj_1');
        final toDelete = files.first;
        repo.deleteFiles({toDelete.id});
        final after = await repo.fetchFiles('obj_1');
        expect(after.any((f) => f.id == toDelete.id), isFalse);
      });

      test('удаляет несколько файлов за раз', () async {
        final files = await repo.fetchFiles('obj_1');
        final ids = {files[0].id, files[1].id};
        final before = files.length;
        repo.deleteFiles(ids);
        final after = await repo.fetchFiles('obj_1');
        expect(after.length, equals(before - 2));
      });

      test('пустой набор ID — не изменяет список файлов', () async {
        final before = (await repo.fetchFiles('obj_1')).length;
        repo.deleteFiles({});
        final after = (await repo.fetchFiles('obj_1')).length;
        expect(after, equals(before));
      });

      test('несуществующий ID — не падает', () async {
        expect(() => repo.deleteFiles({'ghost_id'}), returnsNormally);
      });
    });
  });
}
