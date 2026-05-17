// test/unit/providers/all_files_notifier_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gis_app/providers/app_providers.dart';
import 'package:gis_app/models/app_models.dart';
import '../../helpers/provider_container_helper.dart';
import '../../fixtures/test_fixtures.dart';
import '../../mocks/mock_repository.dart';

void main() {
  setUpAll(registerMockFallbacks);

  final globalFile = makeFileWithObject(
    file: makeFile(id: 'global_1', name: 'ortho.tif', type: FileType.geotiff),
    objectId: '',
    objectName: 'Хранилище',
  );
  final objFile = makeFileWithObject(
    file: makeFile(id: 'obj_f1', name: 'report.pdf', type: FileType.document),
    objectId: 'obj_1',
    objectName: 'Поле №1',
  );
  final seedFiles = [globalFile, objFile];

  ProviderContainer makeContainer(MockAppRepository mock) {
    final c = ProviderContainer(overrides: [repoProvider.overrideWithValue(mock)]);
    addTearDown(c.dispose);
    return c;
  }

  Future<ProviderContainer> makeLoadedContainer(MockAppRepository mock) async {
    final c = makeContainer(mock);
    await awaitNotifierData(c, allFilesProvider);
    return c;
  }

  group('AllFilesNotifier', () {
    late MockAppRepository mock;

    setUp(() {
      mock = MockAppRepository();
      mock.stubFetchAllFiles(seedFiles);
    });

    group('начальная загрузка', () {
      test('загружает все файлы', () async {
        final c = await makeLoadedContainer(mock);
        expect(c.read(allFilesProvider).valueOrNull, hasLength(2));
      });

      test('начинает с loading', () {
        final c = makeContainer(mock);
        expect(c.read(allFilesProvider), isA<AsyncLoading>());
      });
    });

    group('addGlobal', () {
      test('добавляет файл в начало списка', () async {
        final newFile = makeFile(id: 'new_global', name: 'new.tif', type: FileType.geotiff);
        final newFw = makeFileWithObject(file: newFile, objectId: '');
        mock.stubAddGlobalFile(newFw);

        final c = await makeLoadedContainer(mock);
        c.read(allFilesProvider.notifier).addGlobal(newFile);

        final files = c.read(allFilesProvider).valueOrNull!;
        expect(files.first.file.id, equals('new_global'));
        expect(files.length, equals(3));
      });

      test('вызывает repo.addGlobalFile', () async {
        final newFile = makeFile(id: 'call_test');
        final fw = makeFileWithObject(file: newFile, objectId: '');
        mock.stubAddGlobalFile(fw);
        final c = await makeLoadedContainer(mock);
        c.read(allFilesProvider.notifier).addGlobal(newFile);
        verify(() => mock.addGlobalFile(any())).called(1);
      });

      test('не обновляет список если state loading', () {
        final newFile = makeFile(id: 'early_add');
        final fw = makeFileWithObject(file: newFile, objectId: '');
        mock.stubAddGlobalFile(fw);
        final c = makeContainer(mock);
        // State ещё loading
        c.read(allFilesProvider.notifier).addGlobal(newFile);
        expect(c.read(allFilesProvider).valueOrNull, isNull);
      });
    });

    group('addToObject', () {
      test('добавляет файл к объекту', () async {
        final newFile = makeFile(id: 'new_obj_f', name: 'attached.pdf');
        final fw = makeFileWithObject(file: newFile, objectId: 'obj_1');
        mock.stubAddFileToObject(fw);
        final c = await makeLoadedContainer(mock);
        c.read(allFilesProvider.notifier).addToObject('obj_1', newFile);
        final files = c.read(allFilesProvider).valueOrNull!;
        expect(files.any((f) => f.file.id == 'new_obj_f'), isTrue);
        expect(files.first.file.id, equals('new_obj_f'));
      });
    });

    group('delete', () {
      test('удаляет файлы по id', () async {
        mock.stubDeleteFiles();
        final c = await makeLoadedContainer(mock);
        c.read(allFilesProvider.notifier).delete({'global_1'});
        final files = c.read(allFilesProvider).valueOrNull!;
        expect(files.any((f) => f.file.id == 'global_1'), isFalse);
        expect(files.length, equals(1));
      });

      test('удаляет несколько файлов', () async {
        mock.stubDeleteFiles();
        final c = await makeLoadedContainer(mock);
        c.read(allFilesProvider.notifier).delete({'global_1', 'obj_f1'});
        expect(c.read(allFilesProvider).valueOrNull, isEmpty);
      });

      test('вызывает repo.deleteFiles', () async {
        mock.stubDeleteFiles();
        final c = await makeLoadedContainer(mock);
        c.read(allFilesProvider.notifier).delete({'global_1'});
        verify(() => mock.deleteFiles(any())).called(1);
      });
    });

    group('globalFilesProvider', () {
      test('возвращает только файлы без objectId (глобальные)', () async {
        final c = await makeLoadedContainer(mock);
        final globalFiles = c.read(globalFilesProvider);
        expect(globalFiles.any((f) => f.id == 'global_1'), isTrue);
        expect(globalFiles.any((f) => f.id == 'obj_f1'), isFalse);
      });
    });
  });
}
