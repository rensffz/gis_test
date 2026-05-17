// test/unit/models/app_user_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gis_app/models/app_models.dart';
import '../../fixtures/test_fixtures.dart';

void main() {
  group('AppUser', () {
    group('fullName', () {
      test('возвращает "Имя Фамилия" когда оба заполнены', () {
        const user = AppUser(
          id: '1', login: 'u', firstName: 'Иван', lastName: 'Петров',
          organization: 'Org', email: 'i@i.ru',
        );
        expect(user.fullName, equals('Иван Петров'));
      });

      test('возвращает только имя когда фамилия пустая', () {
        const user = AppUser(
          id: '1', login: 'u', firstName: 'Иван', lastName: '',
          organization: 'Org', email: 'i@i.ru',
        );
        expect(user.fullName, equals('Иван'));
      });

      test('возвращает только фамилию когда имя пустое', () {
        const user = AppUser(
          id: '1', login: 'u', firstName: '', lastName: 'Петров',
          organization: 'Org', email: 'i@i.ru',
        );
        expect(user.fullName, equals('Петров'));
      });

      test('возвращает login когда оба пустые', () {
        const user = AppUser(
          id: '1', login: 'johndoe', firstName: '', lastName: '',
          organization: 'Org', email: 'j@j.ru',
        );
        expect(user.fullName, equals('johndoe'));
      });
    });

    group('initials', () {
      test('возвращает заглавные буквы имени и фамилии', () {
        const user = AppUser(
          id: '1', login: 'u', firstName: 'Иван', lastName: 'Петров',
          organization: 'Org', email: 'i@i.ru',
        );
        expect(user.initials, equals('ИП'));
      });

      test('возвращает первую букву имени когда фамилия пустая', () {
        const user = AppUser(
          id: '1', login: 'u', firstName: 'Иван', lastName: '',
          organization: 'Org', email: 'i@i.ru',
        );
        expect(user.initials, equals('И'));
      });

      test('возвращает первую букву логина когда имя и фамилия пустые', () {
        const user = AppUser(
          id: '1', login: 'johndoe', firstName: '', lastName: '',
          organization: 'Org', email: 'j@j.ru',
        );
        expect(user.initials, equals('J'));
      });
    });

    group('copyWith', () {
      test('обновляет только указанные поля', () {
        final updated = kTestUser.copyWith(firstName: 'Новое');
        expect(updated.firstName, equals('Новое'));
        expect(updated.id, equals(kTestUser.id));
        expect(updated.login, equals(kTestUser.login));
        expect(updated.lastName, equals(kTestUser.lastName));
        expect(updated.email, equals(kTestUser.email));
        expect(updated.passwordHash, equals(kTestUser.passwordHash));
      });

      test('обновляет email', () {
        final updated = kTestUser.copyWith(email: 'new@email.com');
        expect(updated.email, equals('new@email.com'));
      });

      test('обновляет организацию', () {
        final updated = kTestUser.copyWith(organization: 'NewOrg');
        expect(updated.organization, equals('NewOrg'));
      });

      test('все поля null — возвращает такой же объект', () {
        final updated = kTestUser.copyWith();
        expect(updated.id, equals(kTestUser.id));
        expect(updated.login, equals(kTestUser.login));
        expect(updated.firstName, equals(kTestUser.firstName));
      });
    });
  });

  group('SavedAccount', () {
    test('хранит все поля', () {
      expect(kTestSavedAccount.login, equals('testuser'));
      expect(kTestSavedAccount.displayName, equals('Тест Пользователь'));
      expect(kTestSavedAccount.initials, equals('ТП'));
    });
  });

  group('GisCategory', () {
    test('хранит все поля', () {
      expect(kTestCategory.id, equals('cat_test'));
      expect(kTestCategory.name, equals('Тестовая категория'));
      expect(kTestCategory.color, isNotNull);
      expect(kTestCategory.icon, isNotNull);
    });
  });
}
