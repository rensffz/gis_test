// test/unit/services/user_api_service_test.dart
// Тесты сетевого слоя: правильность запросов, парсинг ответов,
// обработка ошибок (404, 409, таймаут, нет соединения).

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gis_app/models/app_models.dart';
import 'package:gis_app/services/user_api_service.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late UserApiService service;

  Response<Map<String, dynamic>> _ok(Map<String, dynamic> data) =>
      Response<Map<String, dynamic>>(
        data: data,
        statusCode: 200,
        requestOptions: RequestOptions(path: '/user'),
      );

  Response<Map<String, dynamic>> _noContent() =>
      Response<Map<String, dynamic>>(
        data: null,
        statusCode: 204,
        requestOptions: RequestOptions(path: '/user'),
      );

  DioException _dioError(int statusCode) => DioException(
        requestOptions: RequestOptions(path: '/user'),
        response: Response(
          statusCode: statusCode,
          data: {'message': 'error $statusCode'},
          requestOptions: RequestOptions(path: '/user'),
        ),
        type: DioExceptionType.badResponse,
      );

  DioException _timeout() => DioException(
        requestOptions: RequestOptions(path: '/user'),
        type: DioExceptionType.connectionTimeout,
      );

  DioException _noConnection() => DioException(
        requestOptions: RequestOptions(path: '/user'),
        type: DioExceptionType.connectionError,
      );

  const _userJson = {
    'id': 'u1',
    'login': 'admin',
    'firstName': 'Иван',
    'lastName': 'Петров',
    'organization': 'АгроГИС',
    'email': 'admin@gis.ru',
    'phone': '+7 900 123-45-67',
  };

  setUp(() {
    mockDio = MockDio();
    service = UserApiService.withDio(mockDio);
  });

  group('UserApiService', () {
    // ── GET /user ───────────────────────────────────────────────

    group('getUser', () {
      test('200 → возвращает UserDto с правильными полями', () async {
        when(() => mockDio.get<Map<String, dynamic>>(
              '/user',
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => _ok(_userJson));

        final dto = await service.getUser(id: 'u1');

        expect(dto, isNotNull);
        expect(dto!.id, equals('u1'));
        expect(dto.login, equals('admin'));
        expect(dto.firstName, equals('Иван'));
        expect(dto.email, equals('admin@gis.ru'));
      });

      test('передаёт id как query-параметр', () async {
        when(() => mockDio.get<Map<String, dynamic>>(
              '/user',
              queryParameters: {'id': 'u42'},
            )).thenAnswer((_) async => _ok(_userJson));

        await service.getUser(id: 'u42');

        verify(() => mockDio.get<Map<String, dynamic>>(
              '/user',
              queryParameters: {'id': 'u42'},
            )).called(1);
      });

      test('getUser без id — передаёт null в параметры', () async {
        when(() => mockDio.get<Map<String, dynamic>>(
              '/user',
              queryParameters: null,
            )).thenAnswer((_) async => _ok(_userJson));

        await service.getUser();

        verify(() => mockDio.get<Map<String, dynamic>>(
              '/user',
              queryParameters: null,
            )).called(1);
      });

      test('404 → возвращает null', () async {
        when(() => mockDio.get<Map<String, dynamic>>(
              '/user',
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/user'),
          response: Response(
            statusCode: 404,
            requestOptions: RequestOptions(path: '/user'),
          ),
          type: DioExceptionType.badResponse,
        ));

        final result = await service.getUser(id: 'nonexistent');
        expect(result, isNull);
      });

      test('таймаут → бросает ApiException с сообщением о таймауте', () async {
        when(() => mockDio.get<Map<String, dynamic>>(
              '/user',
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(_timeout());

        expect(
          () => service.getUser(id: 'u1'),
          throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', contains('ожидания'),
          )),
        );
      });

      test('нет соединения → бросает ApiException', () async {
        when(() => mockDio.get<Map<String, dynamic>>(
              '/user',
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(_noConnection());

        expect(
          () => service.getUser(id: 'u1'),
          throwsA(isA<ApiException>().having(
            (e) => e.message, 'message', contains('соединения'),
          )),
        );
      });

      test('data == null → возвращает null', () async {
        when(() => mockDio.get<Map<String, dynamic>>(
              '/user',
              queryParameters: any(named: 'queryParameters'),
            )).thenAnswer((_) async => _noContent());

        final result = await service.getUser(id: 'u1');
        expect(result, isNull);
      });
    });

    // ── POST /user ──────────────────────────────────────────────

    group('createUser', () {
      test('201 → возвращает созданный UserDto', () async {
        when(() => mockDio.post<Map<String, dynamic>>(
              '/user',
              data: any(named: 'data'),
            )).thenAnswer((_) async => _ok(_userJson));

        const dto = UserDto(
          id: 'new_u', login: 'newuser', firstName: 'New',
          lastName: 'User', organization: 'Org', email: 'new@test.ru',
        );
        final result = await service.createUser(dto, 'secret123');

        expect(result, isNotNull);
        expect(result!.login, equals('admin')); // сервер вернул свои данные
      });

      test('включает password в тело запроса', () async {
        Map<String, dynamic>? capturedBody;
        when(() => mockDio.post<Map<String, dynamic>>(
              '/user',
              data: any(named: 'data'),
            )).thenAnswer((inv) async {
          capturedBody = inv.namedArguments[#data] as Map<String, dynamic>;
          return _ok(_userJson);
        });

        const dto = UserDto(
          id: 'u_test', login: 'testuser', firstName: 'T',
          lastName: 'U', organization: 'O', email: 't@u.ru',
        );
        await service.createUser(dto, 'mypassword');

        expect(capturedBody, isNotNull);
        expect(capturedBody!['password'], equals('mypassword'));
        expect(capturedBody!['login'], equals('testuser'));
      });

      test('409 → бросает ApiException с statusCode 409', () async {
        when(() => mockDio.post<Map<String, dynamic>>(
              '/user',
              data: any(named: 'data'),
            )).thenThrow(_dioError(409));

        const dto = UserDto(
          id: 'x', login: 'x', firstName: 'x',
          lastName: 'x', organization: 'x', email: 'x@x.ru',
        );

        expect(
          () => service.createUser(dto, 'pass'),
          throwsA(isA<ApiException>().having(
            (e) => e.statusCode, 'statusCode', equals(409),
          )),
        );
      });

      test('data == null → возвращает null', () async {
        when(() => mockDio.post<Map<String, dynamic>>(
              '/user',
              data: any(named: 'data'),
            )).thenAnswer((_) async => _noContent());

        const dto = UserDto(
          id: 'x', login: 'x', firstName: 'x',
          lastName: 'x', organization: 'x', email: 'x@x.ru',
        );
        final result = await service.createUser(dto, 'pass');
        expect(result, isNull);
      });
    });

    // ── PUT /user ───────────────────────────────────────────────

    group('updateUser', () {
      test('200 → возвращает обновлённый UserDto', () async {
        final updatedJson = Map<String, dynamic>.from(_userJson)
          ..['firstName'] = 'Обновлён';

        when(() => mockDio.put<Map<String, dynamic>>(
              '/user',
              data: any(named: 'data'),
            )).thenAnswer((_) async => _ok(updatedJson));

        const dto = UserDto(
          id: 'u1', login: 'admin', firstName: 'Обновлён',
          lastName: 'Петров', organization: 'АгроГИС', email: 'admin@gis.ru',
        );
        final result = await service.updateUser(dto);

        expect(result!.firstName, equals('Обновлён'));
      });

      test('204 → возвращает исходный dto (локальные данные)', () async {
        when(() => mockDio.put<Map<String, dynamic>>(
              '/user',
              data: any(named: 'data'),
            )).thenAnswer((_) async => _noContent());

        const dto = UserDto(
          id: 'u1', login: 'admin', firstName: 'Local',
          lastName: 'User', organization: 'Org', email: 'a@b.ru',
        );
        final result = await service.updateUser(dto);

        // 204 → возвращаем исходный dto без изменений
        expect(result!.firstName, equals('Local'));
      });

      test('409 → бросает ApiException(409)', () async {
        when(() => mockDio.put<Map<String, dynamic>>(
              '/user',
              data: any(named: 'data'),
            )).thenThrow(_dioError(409));

        const dto = UserDto(
          id: 'x', login: 'x', firstName: 'x',
          lastName: 'x', organization: 'x', email: 'x@x.ru',
        );

        expect(
          () => service.updateUser(dto),
          throwsA(isA<ApiException>().having(
            (e) => e.statusCode, 'statusCode', equals(409),
          )),
        );
      });
    });

    // ── PATCH /user ─────────────────────────────────────────────

    group('updatePassword', () {
      test('успех — не бросает исключений', () async {
        when(() => mockDio.patch<void>(
              '/user',
              data: any(named: 'data'),
            )).thenAnswer((_) async => Response<void>(
              statusCode: 204,
              requestOptions: RequestOptions(path: '/user'),
            ));

        await expectLater(
          service.updatePassword(
            login: 'admin',
            currentPassword: '123456',
            newPassword: 'newpass',
          ),
          completes,
        );
      });

      test('тело содержит login, currentPassword, newPassword', () async {
        Map<String, dynamic>? body;
        when(() => mockDio.patch<void>(
              '/user',
              data: any(named: 'data'),
            )).thenAnswer((inv) async {
          body = inv.namedArguments[#data] as Map<String, dynamic>;
          return Response<void>(
            statusCode: 204,
            requestOptions: RequestOptions(path: '/user'),
          );
        });

        await service.updatePassword(
          login: 'admin',
          currentPassword: 'old',
          newPassword: 'new',
        );

        expect(body!['login'], equals('admin'));
        expect(body!['currentPassword'], equals('old'));
        expect(body!['newPassword'], equals('new'));
      });

      test('ошибка сервера → бросает ApiException', () async {
        when(() => mockDio.patch<void>(
              '/user',
              data: any(named: 'data'),
            )).thenThrow(_dioError(403));

        expect(
          () => service.updatePassword(
            login: 'admin',
            currentPassword: 'wrong',
            newPassword: 'new',
          ),
          throwsA(isA<ApiException>()),
        );
      });
    });

    // ── ApiException ────────────────────────────────────────────

    group('ApiException', () {
      test('сообщение из тела ответа используется если непустое', () async {
        when(() => mockDio.get<Map<String, dynamic>>(
              '/user',
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/user'),
          response: Response(
            statusCode: 500,
            data: {'message': 'Internal Server Error'},
            requestOptions: RequestOptions(path: '/user'),
          ),
          type: DioExceptionType.badResponse,
        ));

        try {
          await service.getUser(id: 'u1');
          fail('должен бросить исключение');
        } on ApiException catch (e) {
          expect(e.message, equals('Internal Server Error'));
          expect(e.statusCode, equals(500));
        }
      });

      test('fallback сообщение если тело пустое', () async {
        when(() => mockDio.get<Map<String, dynamic>>(
              '/user',
              queryParameters: any(named: 'queryParameters'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/user'),
          response: Response(
            statusCode: 503,
            data: null,
            requestOptions: RequestOptions(path: '/user'),
          ),
          type: DioExceptionType.badResponse,
        ));

        try {
          await service.getUser(id: 'u1');
          fail('должен бросить исключение');
        } on ApiException catch (e) {
          expect(e.message, contains('503'));
        }
      });
    });

    // ── UserDto ──────────────────────────────────────────────────

    group('UserDto', () {
      test('fromJson парсит все поля', () {
        const json = {
          'id': 'u1', 'login': 'admin', 'firstName': 'Иван',
          'lastName': 'Петров', 'organization': 'АгроГИС',
          'email': 'admin@gis.ru', 'phone': '+7 900 123-45-67',
        };
        final dto = UserDto.fromJson(json);
        expect(dto.id, equals('u1'));
        expect(dto.phone, equals('+7 900 123-45-67'));
      });

      test('fromJson — отсутствующие поля → пустые строки', () {
        final dto = UserDto.fromJson({});
        expect(dto.id, equals(''));
        expect(dto.login, equals(''));
        expect(dto.phone, equals(''));
      });

      test('toAppUser сохраняет passwordHash из локального состояния', () {
        const dto = UserDto(
          id: 'u1', login: 'admin', firstName: 'X',
          lastName: 'Y', organization: 'Z', email: 'x@y.ru',
        );
        final user = dto.toAppUser(passwordHash: 'local_hash');
        expect(user.passwordHash, equals('local_hash'));
        expect(user.login, equals('admin'));
      });

      test('toAppUser без passwordHash — пустая строка', () {
        const dto = UserDto(
          id: 'u1', login: 'x', firstName: 'x',
          lastName: 'x', organization: 'x', email: 'x@x.ru',
        );
        final user = dto.toAppUser();
        expect(user.passwordHash, equals(''));
      });

      test('fromAppUser не включает passwordHash', () {
        const user = AppUser(
          id: 'u1', login: 'admin', firstName: 'X',
          lastName: 'Y', organization: 'Z', email: 'x@y.ru',
          passwordHash: 'secret',
        );
        final dto = UserDto.fromAppUser(user);
        final json = dto.toJson();
        expect(json.containsKey('password'), isFalse);
        expect(json.containsKey('passwordHash'), isFalse);
      });
    });
  });
}
