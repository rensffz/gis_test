// test/unit/providers/sync_status_test.dart
// Тесты переходов SyncStatus в AuthNotifier.
// Проверяем что background-синхронизация меняет статус правильно
// в зависимости от ответа сервера.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gis_app/models/app_models.dart';
import 'package:gis_app/providers/app_providers.dart';
import 'package:gis_app/services/user_api_service.dart';
import '../../helpers/prefs_helper.dart';
import '../../helpers/provider_container_helper.dart';
import '../../mocks/mock_api_service.dart';

// Ждём пока фоновая синхронизация завершится (не pending).
Future<void> _awaitSync(ProviderContainer c, {int maxMs = 500}) async {
  final sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < maxMs) {
    if (c.read(userSyncStatusProvider) != SyncStatus.pending) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUpAll(registerApiServiceFallbacks);

  Future<ProviderContainer> makeContainer(MockUserApiService api) async {
    final prefs = await createEmptyPrefs();
    return createContainer(prefs, extraOverrides: [
      userApiServiceProvider.overrideWithValue(api),
    ]);
  }

  group('SyncStatus — transitions', () {
    group('после логина', () {
      test('начальный статус — localOnly', () async {
        final api = MockUserApiService();
        final c = await makeContainer(api);
        expect(c.read(userSyncStatusProvider), equals(SyncStatus.localOnly));
      });

      test('сервер вернул пользователя → synced', () async {
        final api = MockUserApiService();
        api.stubGetUser(kServerAdminDto);

        final c = await makeContainer(api);
        await c.read(authProvider.notifier).login('admin', '123456');
        await _awaitSync(c);

        expect(c.read(userSyncStatusProvider), equals(SyncStatus.synced));
      });

      test('сервер вернул null (404) → localOnly', () async {
        final api = MockUserApiService();
        api.stubGetUserNotFound();

        final c = await makeContainer(api);
        await c.read(authProvider.notifier).login('admin', '123456');
        await _awaitSync(c);

        expect(c.read(userSyncStatusProvider), equals(SyncStatus.localOnly));
      });

      test('сервер недоступен (таймаут) → localOnly', () async {
        final api = MockUserApiService();
        api.stubGetUserThrows(
          const ApiException(message: 'Превышено время ожидания сервера'),
        );

        final c = await makeContainer(api);
        await c.read(authProvider.notifier).login('admin', '123456');
        await _awaitSync(c);

        expect(c.read(userSyncStatusProvider), equals(SyncStatus.localOnly));
      });

      test('сервер вернул 409 → conflict', () async {
        final api = MockUserApiService();
        api.stubGetUserThrows(
          const ApiException(statusCode: 409, message: 'Conflict'),
        );

        final c = await makeContainer(api);
        await c.read(authProvider.notifier).login('admin', '123456');
        await _awaitSync(c);

        expect(c.read(userSyncStatusProvider), equals(SyncStatus.conflict));
      });
    });

    group('после регистрации', () {
      test('сервер принял пользователя → synced', () async {
        final api = MockUserApiService();
        api.stubCreateUser(makeUserDto(id: 'new_u', login: 'newuser'));

        final c = await makeContainer(api);
        await c.read(authProvider.notifier).register(
          login: 'newuser', password: 'pass',
          firstName: 'New', lastName: 'User',
          organization: 'Org', email: 'new@test.ru',
        );
        await _awaitSync(c);

        expect(c.read(userSyncStatusProvider), equals(SyncStatus.synced));
      });

      test('сервер недоступен → localOnly (регистрация всё равно успешна)', () async {
        final api = MockUserApiService();
        api.stubCreateUserThrows(
          const ApiException(message: 'Нет соединения с сервером'),
        );

        final c = await makeContainer(api);
        final err = await c.read(authProvider.notifier).register(
          login: 'newuser2', password: 'pass',
          firstName: 'X', lastName: 'Y',
          organization: 'O', email: 'x@y.ru',
        );

        // Регистрация успешна локально
        expect(err, isNull);
        expect(c.read(authProvider), isNotNull);

        await _awaitSync(c);
        expect(c.read(userSyncStatusProvider), equals(SyncStatus.localOnly));
      });
    });

    group('после обновления профиля', () {
      test('сервер принял обновление → synced', () async {
        final api = MockUserApiService();
        api.stubGetUser(kServerAdminDto);
        api.stubUpdateUser(makeUserDto(
          id: 'u1', login: 'admin', firstName: 'Обновлён',
        ));

        final c = await makeContainer(api);
        await c.read(authProvider.notifier).login('admin', '123456');
        await _awaitSync(c);

        final user = c.read(authProvider)!;
        await c.read(authProvider.notifier)
            .updateProfile(user.copyWith(firstName: 'Обновлён'));
        await _awaitSync(c);

        expect(c.read(userSyncStatusProvider), equals(SyncStatus.synced));
      });

      test('сервер вернул 409 → conflict', () async {
        final api = MockUserApiService();
        api.stubGetUser(null);
        api.stubUpdateUserThrows(
          const ApiException(statusCode: 409, message: 'Conflict'),
        );

        final c = await makeContainer(api);
        await c.read(authProvider.notifier).login('admin', '123456');
        await _awaitSync(c);

        final user = c.read(authProvider)!;
        await c.read(authProvider.notifier)
            .updateProfile(user.copyWith(firstName: 'X'));
        await _awaitSync(c);

        expect(c.read(userSyncStatusProvider), equals(SyncStatus.conflict));
      });
    });

    group('после смены пароля', () {
      test('сервер принял → synced', () async {
        final api = MockUserApiService();
        api.stubGetUser(null);
        api.stubUpdatePassword();

        final c = await makeContainer(api);
        await c.read(authProvider.notifier).login('admin', '123456');
        await _awaitSync(c);

        await c.read(authProvider.notifier)
            .changePassword('123456', 'newpass');
        await _awaitSync(c);

        expect(c.read(userSyncStatusProvider), equals(SyncStatus.synced));
      });

      test('сервер недоступен → localOnly (смена пароля локально успешна)', () async {
        final api = MockUserApiService();
        api.stubGetUser(null);
        api.stubUpdatePasswordThrows(
          const ApiException(message: 'Нет соединения'),
        );

        final c = await makeContainer(api);
        await c.read(authProvider.notifier).login('admin', '123456');
        await _awaitSync(c);

        final err = await c.read(authProvider.notifier)
            .changePassword('123456', 'newpass');

        expect(err, isNull); // локально успешно
        await _awaitSync(c);
        expect(c.read(userSyncStatusProvider), equals(SyncStatus.localOnly));
      });
    });

    group('logout сбрасывает статус', () {
      test('logout → localOnly', () async {
        final api = MockUserApiService();
        api.stubGetUser(kServerAdminDto);

        final c = await makeContainer(api);
        await c.read(authProvider.notifier).login('admin', '123456');
        await _awaitSync(c);
        expect(c.read(userSyncStatusProvider), equals(SyncStatus.synced));

        c.read(authProvider.notifier).logout();
        expect(c.read(userSyncStatusProvider), equals(SyncStatus.localOnly));
      });
    });

    group('данные мёрджатся с сервером', () {
      test('сервер вернул новое имя → state обновляется', () async {
        final serverDto = makeUserDto(
          id: 'u1', login: 'admin',
          firstName: 'Серверное', lastName: 'Имя',
        );
        final api = MockUserApiService();
        api.stubGetUser(serverDto);

        final c = await makeContainer(api);
        await c.read(authProvider.notifier).login('admin', '123456');
        await _awaitSync(c);

        final user = c.read(authProvider);
        expect(user?.firstName, equals('Серверное'));
        expect(user?.lastName, equals('Имя'));
      });

      test('passwordHash сохраняется из локального, не с сервера', () async {
        final api = MockUserApiService();
        api.stubGetUser(kServerAdminDto);

        final c = await makeContainer(api);
        await c.read(authProvider.notifier).login('admin', '123456');
        await _awaitSync(c);

        // Пароль хранится локально и не перезаписывается сервером
        final user = c.read(authProvider);
        expect(user?.passwordHash, equals('123456'));
      });
    });
  });
}
