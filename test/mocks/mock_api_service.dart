// test/mocks/mock_api_service.dart
import 'package:mocktail/mocktail.dart';
import 'package:gis_app/services/user_api_service.dart';
import 'package:gis_app/models/app_models.dart';

class MockUserApiService extends Mock implements UserApiService {}

void registerApiServiceFallbacks() {
  registerFallbackValue(const UserDto(
    id: 'fb', login: 'fb', firstName: 'fb', lastName: 'fb',
    organization: 'fb', email: 'fb@fb.com',
  ));
}

extension MockApiStubs on MockUserApiService {
  void stubGetUser(UserDto? result) {
    when(() => getUser(id: any(named: 'id')))
        .thenAnswer((_) async => result);
  }

  void stubGetUserThrows(Exception e) {
    when(() => getUser(id: any(named: 'id'))).thenThrow(e);
  }

  void stubGetUserNotFound() {
    when(() => getUser(id: any(named: 'id')))
        .thenAnswer((_) async => null);
  }

  void stubCreateUser(UserDto? result) {
    when(() => createUser(any(), any())).thenAnswer((_) async => result);
  }

  void stubCreateUserThrows(Exception e) {
    when(() => createUser(any(), any())).thenThrow(e);
  }

  void stubUpdateUser(UserDto? result) {
    when(() => updateUser(any())).thenAnswer((_) async => result);
  }

  void stubUpdateUserThrows(Exception e) {
    when(() => updateUser(any())).thenThrow(e);
  }

  void stubUpdatePassword() {
    when(() => updatePassword(
          login: any(named: 'login'),
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        )).thenAnswer((_) async {});
  }

  void stubUpdatePasswordThrows(Exception e) {
    when(() => updatePassword(
          login: any(named: 'login'),
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        )).thenThrow(e);
  }
}

// DTO фабрики для тестов
UserDto makeUserDto({
  String id = 'u_dto',
  String login = 'dtouser',
  String firstName = 'Dto',
  String lastName = 'User',
  String organization = 'Org',
  String email = 'dto@test.ru',
  String phone = '',
}) =>
    UserDto(
      id: id,
      login: login,
      firstName: firstName,
      lastName: lastName,
      organization: organization,
      email: email,
      phone: phone,
    );

const kServerAdminDto = UserDto(
  id: 'u1',
  login: 'admin',
  firstName: 'Иван',
  lastName: 'Петров',
  organization: 'АгроГИС',
  email: 'admin@gis.ru',
  phone: '+7 900 123-45-67',
);
