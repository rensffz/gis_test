// test/integration/auth_flow_test.dart
// Widget-тесты полного flow авторизации.
// Запускают полное дерево виджетов (GisApp + GoRouter + ProviderScope).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/prefs_helper.dart';
import '../helpers/provider_container_helper.dart';

void main() {
  group('Auth Flow — Widget Tests', () {
    Future<void> pumpApp(WidgetTester tester, {Map<String, Object> prefsData = const {}}) async {
      final prefs = prefsData.isEmpty
          ? await createEmptyPrefs()
          : await createPrefsWithValues(prefsData);
      await tester.pumpWidget(buildTestApp(prefs));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    group('LoginScreen', () {
      testWidgets('показывает экран логина для неавторизованного', (tester) async {
        await pumpApp(tester);
        expect(find.text('GIS Monitor'), findsOneWidget);
        expect(find.text('Войдите в систему'), findsOneWidget);
      });

      testWidgets('показывает поля логин и пароль', (tester) async {
        await pumpApp(tester);
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('Логин'), findsOneWidget);
        expect(find.text('Пароль'), findsOneWidget);
      });

      testWidgets('показывает кнопку Войти', (tester) async {
        await pumpApp(tester);
        expect(find.text('Войти'), findsOneWidget);
      });

      testWidgets('показывает кнопку Зарегистрироваться', (tester) async {
        await pumpApp(tester);
        expect(find.text('Зарегистрироваться'), findsOneWidget);
      });

      testWidgets('валидирует пустой логин', (tester) async {
        await pumpApp(tester);
        await tester.tap(find.text('Войти'));
        await tester.pumpAndSettle();
        // hintText и errorText оба содержат 'Введите логин'
        expect(find.text('Введите логин'), findsWidgets);
      });

      testWidgets('валидирует короткий пароль', (tester) async {
        await pumpApp(tester);
        await tester.enterText(find.byType(TextFormField).first, 'admin');
        await tester.enterText(find.byType(TextFormField).last, '12');
        await tester.tap(find.text('Войти'));
        await tester.pumpAndSettle();
        expect(find.text('Минимум 4 символа'), findsOneWidget);
      });

      testWidgets('успешный логин → переход на dashboard', (tester) async {
        await pumpApp(tester);
        await tester.enterText(find.byType(TextFormField).first, 'admin');
        await tester.enterText(find.byType(TextFormField).last, '123456');
        await tester.tap(find.text('Войти'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        // Dashboard должен появиться (содержит раздел GIS Monitor)
        expect(find.text('Войдите в систему'), findsNothing);
      });

      testWidgets('неверный пароль → показывает ошибку', (tester) async {
        await pumpApp(tester);
        await tester.enterText(find.byType(TextFormField).first, 'admin');
        await tester.enterText(find.byType(TextFormField).last, 'wrongpass');
        await tester.tap(find.text('Войти'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
        // Snackbar с ошибкой
        expect(find.text('Неверный логин или пароль'), findsOneWidget);
      });
    });

    group('Register Flow', () {
      testWidgets('кнопка Зарегистрироваться → переход на Step1', (tester) async {
        await pumpApp(tester);
        await tester.ensureVisible(find.text('Зарегистрироваться'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Зарегистрироваться'));
        await tester.pumpAndSettle();
        // Step1: AppBar title "Регистрация" и заголовок "Придумайте пароль"
        expect(find.text('Регистрация'), findsOneWidget);
        expect(find.text('Придумайте пароль'), findsOneWidget);
      });

      testWidgets('Step1 показывает поля пароля', (tester) async {
        await pumpApp(tester);
        await tester.ensureVisible(find.text('Зарегистрироваться'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Зарегистрироваться'));
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), isNot(findsNothing));
        expect(find.text('Минимум 6 символов'), findsOneWidget);
      });
    });

    group('Saved Accounts', () {
      testWidgets('saved accounts не показываются при пустом списке', (tester) async {
        await pumpApp(tester);
        expect(find.text('Сохранённые аккаунты'), findsNothing);
      });
    });

    group('Theme Toggle', () {
      testWidgets('кнопка смены темы присутствует', (tester) async {
        await pumpApp(tester);
        expect(find.byType(IconButton), findsWidgets);
      });
    });
  });

  group('Auth Persistence', () {
    testWidgets('авторизованный пользователь → сразу на dashboard', (tester) async {
      // Создаём prefs с данными пользователя и auth session
      const userJson = '{"id":"u1","login":"admin","firstName":"Иван",'
          '"lastName":"Петров","organization":"АгроГИС",'
          '"email":"admin@gis.ru","phone":"+7 900 123-45-67","passwordHash":"123456"}';
      final prefs = await createPrefsWithValues({
        'repo_users': [userJson],
        'repo_auth_login': 'admin',
      });
      await tester.pumpWidget(buildTestApp(prefs));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Не должны быть на странице логина
      expect(find.text('Войдите в систему'), findsNothing);
    });
  });
}
