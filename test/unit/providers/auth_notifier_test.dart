// test/unit/providers/auth_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gis_app/models/app_models.dart';
import 'package:gis_app/providers/app_providers.dart';
import 'package:gis_app/repositories/app_repository.dart';
import '../../helpers/prefs_helper.dart';
import '../../helpers/provider_container_helper.dart';
import '../../fixtures/test_fixtures.dart';
import '../../mocks/mock_repository.dart';

void main() {
  setUpAll(registerMockFallbacks);

  group('AuthNotifier', () {
    // Хелпер: создаёт контейнер с реальным репозиторием и mock prefs
    Future<ProviderContainer> makeContainer({Map<String, Object> prefsData = const {}}) async {
      final prefs = prefsData.isEmpty
          ? await createEmptyPrefs()
          : await createPrefsWithValues(prefsData);
      return createContainer(prefs);
    }

    group('начальное состояние', () {
      test('state == null при пустых prefs', () async {
        final c = await makeContainer();
        expect(c.read(authProvider), isNull);
      });

      test('state != null если в prefs сохранён auth', () async {
        // Регистрируем пользователя, сохраняем prefs
        final prefs = await createEmptyPrefs();
        final repo = AppRepository(prefs);
        await repo.register(
          login: 'saved', password: 'pass', firstName: 'A',
          lastName: 'B', organization: 'Org', email: 'a@b.ru',
        );
        repo.persistAuth('saved');
        // Создаём контейнер с теми же prefs — должен восстановить сессию
        final c = createContainer(prefs);
        expect(c.read(authProvider), isNotNull);
        expect(c.read(authProvider)!.login, equals('saved'));
      });
    });

    group('login', () {
      test('устанавливает state после успешного логина', () async {
        final c = await makeContainer();
        final err = await c.read(authProvider.notifier).login('admin', '123456');
        expect(err, isNull);
        expect(c.read(authProvider), isNotNull);
        expect(c.read(authProvider)!.login, equals('admin'));
      });

      test('возвращает сообщение об ошибке при неверных данных', () async {
        final c = await makeContainer();
        final err = await c.read(authProvider.notifier).login('admin', 'wrong');
        expect(err, isNotNull);
        expect(c.read(authProvider), isNull);
      });

      test('сохраняет аккаунт в saved accounts', () async {
        final c = await makeContainer();
        await c.read(authProvider.notifier).login('admin', '123456');
        final saved = c.read(authProvider.notifier).savedAccounts;
        expect(saved.any((a) => a.login == 'admin'), isTrue);
      });
    });

    group('register', () {
      test('регистрирует нового пользователя и логинит', () async {
        final c = await makeContainer();
        final err = await c.read(authProvider.notifier).register(
          login: 'newuser', password: 'pass123',
          firstName: 'New', lastName: 'User',
          organization: 'Org', email: 'new@test.ru',
        );
        expect(err, isNull);
        expect(c.read(authProvider), isNotNull);
        expect(c.read(authProvider)!.login, equals('newuser'));
      });

      test('возвращает ошибку если логин занят', () async {
        final c = await makeContainer();
        // admin уже существует как seed
        final err = await c.read(authProvider.notifier).register(
          login: 'admin', password: 'pass',
          firstName: 'X', lastName: 'Y',
          organization: 'Org', email: 'x@y.ru',
        );
        expect(err, isNotNull);
        expect(err, contains('занят'));
      });
    });

    group('logout', () {
      test('устанавливает state в null', () async {
        final c = await makeContainer();
        await c.read(authProvider.notifier).login('admin', '123456');
        expect(c.read(authProvider), isNotNull);
        c.read(authProvider.notifier).logout();
        expect(c.read(authProvider), isNull);
      });

      test('сохраняет аккаунт перед logout', () async {
        final c = await makeContainer();
        await c.read(authProvider.notifier).login('admin', '123456');
        c.read(authProvider.notifier).logout();
        final saved = c.read(authProvider.notifier).savedAccounts;
        expect(saved.any((a) => a.login == 'admin'), isTrue);
      });
    });

    group('isLoggedIn', () {
      test('false при null state', () async {
        final c = await makeContainer();
        expect(c.read(authProvider.notifier).isLoggedIn, isFalse);
      });

      test('true после логина', () async {
        final c = await makeContainer();
        await c.read(authProvider.notifier).login('admin', '123456');
        expect(c.read(authProvider.notifier).isLoggedIn, isTrue);
      });
    });

    group('updateProfile', () {
      test('обновляет state', () async {
        final c = await makeContainer();
        await c.read(authProvider.notifier).login('admin', '123456');
        final user = c.read(authProvider)!;
        final err = await c.read(authProvider.notifier)
            .updateProfile(user.copyWith(firstName: 'Новое'));
        expect(err, isNull);
        expect(c.read(authProvider)!.firstName, equals('Новое'));
      });

      test('возвращает ошибку если логин занят', () async {
        final c = await makeContainer();
        await c.read(authProvider.notifier).register(
          login: 'user2', password: 'p', firstName: 'U', lastName: '2',
          organization: 'O', email: 'u@2.ru',
        );
        await c.read(authProvider.notifier).login('admin', '123456');
        final admin = c.read(authProvider)!;
        final err = await c.read(authProvider.notifier)
            .updateProfile(admin.copyWith(login: 'user2'));
        expect(err, isNotNull);
      });
    });

    group('changePassword', () {
      test('успешная смена — нет ошибки', () async {
        final c = await makeContainer();
        await c.read(authProvider.notifier).login('admin', '123456');
        final err = await c.read(authProvider.notifier)
            .changePassword('123456', 'newpass');
        expect(err, isNull);
      });

      test('возвращает ошибку при неверном текущем пароле', () async {
        final c = await makeContainer();
        await c.read(authProvider.notifier).login('admin', '123456');
        final err = await c.read(authProvider.notifier)
            .changePassword('wrong', 'newpass');
        expect(err, isNotNull);
      });

      test('возвращает ошибку если не авторизован', () async {
        final c = await makeContainer();
        final err = await c.read(authProvider.notifier)
            .changePassword('pass', 'newpass');
        expect(err, isNotNull);
      });
    });

    group('quickLogin', () {
      test('логинит из saved accounts', () async {
        final c = await makeContainer();
        await c.read(authProvider.notifier).login('admin', '123456');
        c.read(authProvider.notifier).logout();
        expect(c.read(authProvider), isNull);
        c.read(authProvider.notifier).quickLogin('admin');
        expect(c.read(authProvider), isNotNull);
        expect(c.read(authProvider)!.login, equals('admin'));
      });

      test('несуществующий логин — не меняет state', () async {
        final c = await makeContainer();
        c.read(authProvider.notifier).quickLogin('ghost');
        expect(c.read(authProvider), isNull);
      });
    });

    group('savedAccounts', () {
      test('возвращает пустой список изначально', () async {
        final c = await makeContainer();
        expect(c.read(authProvider.notifier).savedAccounts, isEmpty);
      });

      test('содержит аккаунт после логина', () async {
        final c = await makeContainer();
        await c.read(authProvider.notifier).login('admin', '123456');
        expect(c.read(authProvider.notifier).savedAccounts, hasLength(1));
      });
    });

    group('removeSavedAccount', () {
      test('удаляет аккаунт из репозитория', () async {
        final c = await makeContainer();
        await c.read(authProvider.notifier).login('admin', '123456');
        c.read(authProvider.notifier).removeSavedAccount('admin');
        expect(c.read(authProvider.notifier).savedAccounts, isEmpty);
      });
    });
  });
}
