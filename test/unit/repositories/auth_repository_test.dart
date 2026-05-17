// test/unit/repositories/auth_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gis_app/repositories/app_repository.dart';
import 'package:gis_app/models/app_models.dart';
import '../../helpers/prefs_helper.dart';

void main() {
  late SharedPreferences prefs;
  late AppRepository repo;

  setUp(() async {
    prefs = await createEmptyPrefs();
    repo = AppRepository(prefs);
  });

  group('AppRepository — Auth', () {
    group('login', () {
      test('возвращает пользователя при верных данных', () async {
        // Seed admin создаётся автоматически при первом запуске
        final user = await repo.login('admin', '123456');
        expect(user, isNotNull);
        expect(user!.login, equals('admin'));
      });

      test('возвращает null при неверном пароле', () async {
        final user = await repo.login('admin', 'wrong_password');
        expect(user, isNull);
      });

      test('возвращает null при несуществующем логине', () async {
        final user = await repo.login('nonexistent', '123456');
        expect(user, isNull);
      });

      test('возвращает null для пустых данных', () async {
        final user = await repo.login('', '');
        expect(user, isNull);
      });

      test('логин чувствителен к регистру', () async {
        final user = await repo.login('Admin', '123456');
        expect(user, isNull); // 'Admin' != 'admin'
      });
    });

    group('register', () {
      test('создаёт нового пользователя', () async {
        final user = await repo.register(
          login: 'newuser',
          password: 'pass123',
          firstName: 'Новый',
          lastName: 'Пользователь',
          organization: 'ТестОрг',
          email: 'new@test.ru',
        );
        expect(user.login, equals('newuser'));
        expect(user.firstName, equals('Новый'));
        expect(user.email, equals('new@test.ru'));
        expect(user.id, isNotEmpty);
      });

      test('зарегистрированный пользователь может войти', () async {
        await repo.register(
          login: 'newuser', password: 'pass123',
          firstName: 'Новый', lastName: 'Пользователь',
          organization: 'Org', email: 'new@test.ru',
        );
        final logged = await repo.login('newuser', 'pass123');
        expect(logged, isNotNull);
        expect(logged!.login, equals('newuser'));
      });

      test('регистрация сохраняется в SharedPreferences', () async {
        await repo.register(
          login: 'saved_user', password: 'pass',
          firstName: 'A', lastName: 'B',
          organization: 'Org', email: 'a@b.ru',
        );
        // Создаём новый репозиторий с теми же prefs
        final repo2 = AppRepository(prefs);
        final user = await repo2.login('saved_user', 'pass');
        expect(user, isNotNull);
      });

      test('генерирует уникальный id', () async {
        final u1 = await repo.register(
          login: 'u1', password: 'p', firstName: 'A', lastName: 'B',
          organization: 'Org', email: 'a@a.ru',
        );
        await Future.delayed(const Duration(milliseconds: 5));
        final u2 = await repo.register(
          login: 'u2', password: 'p', firstName: 'C', lastName: 'D',
          organization: 'Org', email: 'b@b.ru',
        );
        expect(u1.id, isNot(equals(u2.id)));
      });
    });

    group('isLoginTaken', () {
      test('true для существующего логина', () {
        expect(repo.isLoginTaken('admin'), isTrue);
      });

      test('false для несуществующего логина', () {
        expect(repo.isLoginTaken('no_such_user'), isFalse);
      });

      test('excludeId исключает текущего пользователя', () async {
        final user = await repo.login('admin', '123456');
        // admin может сохранить свой логин при обновлении профиля
        expect(repo.isLoginTaken('admin', excludeId: user!.id), isFalse);
      });

      test('excludeId не исключает других пользователей', () async {
        await repo.register(
          login: 'other', password: 'p', firstName: 'O', lastName: 'O',
          organization: 'Org', email: 'o@o.ru',
        );
        expect(repo.isLoginTaken('other', excludeId: 'some_other_id'), isTrue);
      });
    });

    group('updateProfile', () {
      test('обновляет данные пользователя', () async {
        final admin = await repo.login('admin', '123456');
        final updated = admin!.copyWith(firstName: 'Новое имя');
        final saved = await repo.updateProfile(updated);
        expect(saved.firstName, equals('Новое имя'));
      });

      test('обновление сохраняется в prefs', () async {
        final admin = await repo.login('admin', '123456');
        await repo.updateProfile(admin!.copyWith(firstName: 'Изменено'));
        final repo2 = AppRepository(prefs);
        final reloaded = repo2.getUserByLogin('admin');
        expect(reloaded!.firstName, equals('Изменено'));
      });
    });

    group('changePassword', () {
      test('успешная смена пароля возвращает null (нет ошибки)', () async {
        final err = await repo.changePassword('admin', '123456', 'newpass');
        expect(err, isNull);
      });

      test('можно войти после смены пароля', () async {
        await repo.changePassword('admin', '123456', 'newpass123');
        final user = await repo.login('admin', 'newpass123');
        expect(user, isNotNull);
      });

      test('старый пароль перестаёт работать', () async {
        await repo.changePassword('admin', '123456', 'newpass');
        final user = await repo.login('admin', '123456');
        expect(user, isNull);
      });

      test('неверный текущий пароль возвращает сообщение об ошибке', () async {
        final err = await repo.changePassword('admin', 'wrong', 'newpass');
        expect(err, isNotNull);
        expect(err, contains('пароль'));
      });

      test('несуществующий пользователь — ошибка', () async {
        final err = await repo.changePassword('nouser', 'pass', 'newpass');
        expect(err, isNotNull);
      });
    });

    group('savedAccounts', () {
      test('getSavedAccounts возвращает пустой список изначально', () {
        expect(repo.getSavedAccounts(), isEmpty);
      });

      test('saveAccount добавляет аккаунт', () async {
        final user = await repo.login('admin', '123456');
        repo.saveAccount(user!);
        expect(repo.getSavedAccounts(), hasLength(1));
        expect(repo.getSavedAccounts().first.login, equals('admin'));
      });

      test('saveAccount обновляет существующий (не дублирует)', () async {
        final user = await repo.login('admin', '123456');
        repo.saveAccount(user!);
        repo.saveAccount(user);
        expect(repo.getSavedAccounts(), hasLength(1));
      });

      test('removeSavedAccount удаляет аккаунт', () async {
        final user = await repo.login('admin', '123456');
        repo.saveAccount(user!);
        repo.removeSavedAccount('admin');
        expect(repo.getSavedAccounts(), isEmpty);
      });

      test('saveAccount сохраняется в prefs', () async {
        final user = await repo.login('admin', '123456');
        repo.saveAccount(user!);
        final repo2 = AppRepository(prefs);
        expect(repo2.getSavedAccounts(), hasLength(1));
      });

      test('removeSavedAccount несуществующего — не падает', () {
        expect(() => repo.removeSavedAccount('ghost'), returnsNormally);
      });
    });

    group('auth persistence', () {
      test('restoredLogin возвращает null изначально', () {
        expect(repo.restoredLogin, isNull);
      });

      test('persistAuth сохраняет логин', () {
        repo.persistAuth('admin');
        expect(repo.restoredLogin, equals('admin'));
      });

      test('clearAuth удаляет сохранённый логин', () {
        repo.persistAuth('admin');
        repo.clearAuth();
        expect(repo.restoredLogin, isNull);
      });

      test('restoredLogin восстанавливается после пересоздания репозитория', () {
        repo.persistAuth('admin');
        final repo2 = AppRepository(prefs);
        expect(repo2.restoredLogin, equals('admin'));
      });
    });

    group('getUserByLogin', () {
      test('возвращает admin пользователя', () {
        final user = repo.getUserByLogin('admin');
        expect(user, isNotNull);
        expect(user!.login, equals('admin'));
      });

      test('возвращает null для несуществующего', () {
        final user = repo.getUserByLogin('nonexistent');
        expect(user, isNull);
      });
    });

    group('updateSavedAccount', () {
      test('обновляет запись в saved accounts', () async {
        final user = await repo.login('admin', '123456');
        repo.saveAccount(user!);
        final updated = user.copyWith(firstName: 'Новое', lastName: 'Имя');
        repo.updateSavedAccount('admin', updated);
        final saved = repo.getSavedAccounts().first;
        expect(saved.displayName, equals('Новое Имя'));
      });

      test('несуществующий logon — не падает', () async {
        final user = await repo.login('admin', '123456');
        expect(
          () => repo.updateSavedAccount('ghost', user!),
          returnsNormally,
        );
      });
    });
  });
}
