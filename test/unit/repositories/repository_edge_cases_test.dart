// test/unit/repositories/repository_edge_cases_test.dart
// Граничные случаи репозитория, не покрытые в основных тестах.

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

  group('AppRepository — edge cases', () {

    // ── isLoginTaken с excludeId ──────────────────────────────

    group('isLoginTaken с excludeId', () {
      test('текущий пользователь не считается занятым при excludeId', () async {
        // admin уже существует как seed (id: u1)
        final taken = repo.isLoginTaken('admin', excludeId: 'u1');
        expect(taken, isFalse);
      });

      test('другой пользователь с тем же логином — занято', () async {
        await repo.register(
          login: 'user2', password: 'p', firstName: 'U',
          lastName: '2', organization: 'O', email: 'u@2.ru',
        );
        // admin пытается взять логин user2 — занято (другой id)
        final taken = repo.isLoginTaken('user2', excludeId: 'u1');
        expect(taken, isTrue);
      });

      test('несуществующий логин — не занят', () {
        final taken = repo.isLoginTaken('ghost_login', excludeId: 'u1');
        expect(taken, isFalse);
      });

      test('без excludeId — собственный логин тоже считается занятым', () {
        final taken = repo.isLoginTaken('admin');
        expect(taken, isTrue);
      });
    });

    // ── updateSavedAccount при смене логина ───────────────────

    group('updateSavedAccount', () {
      test('обновляет логин в saved accounts', () async {
        final user = await repo.login('admin', '123456');
        repo.saveAccount(user!);

        final updated = AppUser(
          id: user.id, login: 'admin_renamed',
          firstName: user.firstName, lastName: user.lastName,
          organization: user.organization, email: user.email,
          passwordHash: user.passwordHash,
        );
        repo.updateSavedAccount('admin', updated);

        final accounts = repo.getSavedAccounts();
        expect(accounts.any((a) => a.login == 'admin_renamed'), isTrue);
        expect(accounts.any((a) => a.login == 'admin'), isFalse);
      });

      test('несуществующий старый логин — не падает', () {
        final updated = AppUser(
          id: 'u1', login: 'new', firstName: 'X', lastName: 'Y',
          organization: 'O', email: 'x@y.ru',
        );
        expect(() => repo.updateSavedAccount('ghost', updated), returnsNormally);
      });

      test('displayName обновляется корректно', () async {
        final user = await repo.login('admin', '123456');
        repo.saveAccount(user!);

        final updated = AppUser(
          id: user.id, login: 'admin',
          firstName: 'Новое', lastName: 'Имя',
          organization: user.organization, email: user.email,
          passwordHash: user.passwordHash,
        );
        repo.updateSavedAccount('admin', updated);

        final accounts = repo.getSavedAccounts();
        final found = accounts.firstWhere((a) => a.login == 'admin');
        expect(found.displayName, equals('Новое Имя'));
        expect(found.initials, equals('НИ'));
      });
    });

    // ── attachFileToObject — дублирование ─────────────────────

    group('attachFileToObject — дедупликация', () {
      test('прикрепление одного файла дважды — не дублируется', () async {
        await repo.fetchLayers('obj_1'); // init cache

        final file = makeFile(id: 'unique_file', name: 'test.tif',
            type: FileType.geotiff, sizeBytes: 1024);

        // Прикрепляем дважды
        repo.attachFileToObject('obj_1', file);
        repo.attachFileToObject('obj_1', file);

        final files = await repo.fetchFiles('obj_1');
        final count = files.where((f) => f.id == 'unique_file').length;
        expect(count, equals(1));
      });

      test('прикрепление разных файлов — оба появляются', () async {
        final f1 = makeFile(id: 'file_a', name: 'a.tif');
        final f2 = makeFile(id: 'file_b', name: 'b.tif');

        repo.attachFileToObject('obj_1', f1);
        repo.attachFileToObject('obj_1', f2);

        final files = await repo.fetchFiles('obj_1');
        expect(files.any((f) => f.id == 'file_a'), isTrue);
        expect(files.any((f) => f.id == 'file_b'), isTrue);
      });
    });

    // ── deleteFiles на пустом множестве ──────────────────────

    group('deleteFiles', () {
      test('пустое множество — не падает', () {
        expect(() => repo.deleteFiles({}), returnsNormally);
      });

      test('несуществующие id — не падает', () {
        expect(() => repo.deleteFiles({'ghost_id_1', 'ghost_id_2'}),
            returnsNormally);
      });

      test('удаляет файл из globalFiles', () async {
        final file = makeFile(id: 'del_file', name: 'to_delete.tif');
        repo.addGlobalFile(file);

        final before = repo.getGlobalFiles();
        expect(before.any((f) => f.id == 'del_file'), isTrue);

        repo.deleteFiles({'del_file'});

        final after = repo.getGlobalFiles();
        expect(after.any((f) => f.id == 'del_file'), isFalse);
      });

      test('удаляет файл из filesCache объекта', () async {
        final file = makeFile(id: 'cached_file', name: 'cached.tif');
        repo.addFileToObject('obj_1', file);

        repo.deleteFiles({'cached_file'});

        final files = await repo.fetchFiles('obj_1');
        expect(files.any((f) => f.id == 'cached_file'), isFalse);
      });

      test('удаляет файлы из нескольких объектов одновременно', () async {
        final f1 = makeFile(id: 'multi_f1', name: 'f1.tif');
        final f2 = makeFile(id: 'multi_f2', name: 'f2.tif');
        repo.addFileToObject('obj_1', f1);
        repo.addFileToObject('obj_2', f2);

        repo.deleteFiles({'multi_f1', 'multi_f2'});

        final files1 = await repo.fetchFiles('obj_1');
        final files2 = await repo.fetchFiles('obj_2');
        expect(files1.any((f) => f.id == 'multi_f1'), isFalse);
        expect(files2.any((f) => f.id == 'multi_f2'), isFalse);
      });
    });

    // ── getGlobalFiles ─────────────────────────────────────────

    group('getGlobalFiles', () {
      test('возвращает seed-файлы', () {
        final files = repo.getGlobalFiles();
        expect(files, isNotEmpty);
      });

      test('список неизменяемый', () {
        final files = repo.getGlobalFiles();
        expect(() => (files as dynamic).add(null), throwsA(anything));
      });

      test('добавленный файл появляется в списке', () {
        final file = makeFile(id: 'global_new', name: 'new.tif');
        repo.addGlobalFile(file);
        final files = repo.getGlobalFiles();
        expect(files.any((f) => f.id == 'global_new'), isTrue);
      });
    });

    // ── SyncStatus persistence ─────────────────────────────────

    group('SyncStatus persistence', () {
      test('getSyncStatus возвращает localOnly по умолчанию', () {
        expect(repo.getSyncStatus(), equals(SyncStatus.localOnly));
      });

      test('persistSyncStatus сохраняет и восстанавливается', () async {
        repo.persistSyncStatus(SyncStatus.synced);
        expect(repo.getSyncStatus(), equals(SyncStatus.synced));
      });

      test('все статусы сохраняются корректно', () {
        for (final status in SyncStatus.values) {
          repo.persistSyncStatus(status);
          expect(repo.getSyncStatus(), equals(status));
        }
      });

      test('статус восстанавливается при пересоздании репо', () async {
        repo.persistSyncStatus(SyncStatus.synced);
        // Пересоздаём репозиторий с теми же prefs
        final prefs = await createPrefsWithValues({
          'repo_sync_status': 'synced',
        });
        final repo2 = AppRepository(prefs);
        expect(repo2.getSyncStatus(), equals(SyncStatus.synced));
      });
    });

    // ── fetchLayers граничные случаи ──────────────────────────

    group('fetchLayers — граничные случаи', () {
      test('обращение к несуществующему objectId — пустой список', () async {
        final layers = await repo.fetchLayers('obj_9999_nonexistent');
        expect(layers, isEmpty);
      });

      test('независимость кэшей разных объектов', () async {
        await repo.addLayer('obj_1', makeLayer(id: 'only_in_1', name: 'Only 1'));
        final l1 = await repo.fetchLayers('obj_1');
        final l2 = await repo.fetchLayers('obj_2');
        expect(l1.any((l) => l.id == 'only_in_1'), isTrue);
        expect(l2.any((l) => l.id == 'only_in_1'), isFalse);
      });
    });

    // ── register — поля сохраняются ───────────────────────────

    group('register — хранение данных', () {
      test('все поля пользователя сохраняются', () async {
        final user = await repo.register(
          login: 'fulluser',
          password: 'pass',
          firstName: 'Иван',
          lastName: 'Иванов',
          organization: 'ТестОрг',
          email: 'ivan@test.ru',
        );

        expect(user.login, equals('fulluser'));
        expect(user.firstName, equals('Иван'));
        expect(user.lastName, equals('Иванов'));
        expect(user.organization, equals('ТестОрг'));
        expect(user.email, equals('ivan@test.ru'));
        expect(user.passwordHash, equals('pass'));
      });

      test('id генерируется уникально для каждого пользователя', () async {
        final u1 = await repo.register(
          login: 'u_a', password: 'p', firstName: 'A', lastName: 'A',
          organization: 'O', email: 'a@a.ru',
        );
        await Future<void>.delayed(const Duration(milliseconds: 2));
        final u2 = await repo.register(
          login: 'u_b', password: 'p', firstName: 'B', lastName: 'B',
          organization: 'O', email: 'b@b.ru',
        );
        expect(u1.id, isNot(equals(u2.id)));
      });

      test('phone по умолчанию пустая строка', () async {
        final user = await repo.register(
          login: 'nophone', password: 'p', firstName: 'X', lastName: 'Y',
          organization: 'O', email: 'x@y.ru',
        );
        expect(user.phone, equals(''));
      });
    });

    // ── saveAccount — порядок ─────────────────────────────────

    group('saveAccount — порядок', () {
      test('последний залогиненный — первый в списке', () async {
        final u1 = await repo.register(
          login: 'first_u', password: 'p', firstName: 'F', lastName: 'F',
          organization: 'O', email: 'f@f.ru',
        );
        final u2 = await repo.register(
          login: 'second_u', password: 'p', firstName: 'S', lastName: 'S',
          organization: 'O', email: 's@s.ru',
        );

        repo.saveAccount(u1);
        repo.saveAccount(u2);

        final accounts = repo.getSavedAccounts();
        expect(accounts.first.login, equals('second_u'));
      });

      test('повторный saveAccount переносит аккаунт в начало', () async {
        final u1 = await repo.register(
          login: 'repeat_u', password: 'p', firstName: 'R', lastName: 'R',
          organization: 'O', email: 'r@r.ru',
        );
        final u2 = await repo.register(
          login: 'other_u', password: 'p', firstName: 'O', lastName: 'O',
          organization: 'O', email: 'o@o.ru',
        );

        repo.saveAccount(u1);
        repo.saveAccount(u2);
        repo.saveAccount(u1); // снова сохраняем u1

        final accounts = repo.getSavedAccounts();
        expect(accounts.first.login, equals('repeat_u'));
        // u1 не дублируется
        expect(accounts.where((a) => a.login == 'repeat_u').length, equals(1));
      });
    });
  });
}
