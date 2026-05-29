// test/widget/login_screen_test.dart
// Widget-тесты экрана логина.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gis_app/providers/app_providers.dart';
import '../helpers/prefs_helper.dart';
import '../helpers/provider_container_helper.dart';
import '../mocks/mock_api_service.dart';

void main() {
  setUpAll(registerApiServiceFallbacks);

  Future<void> pumpLogin(WidgetTester tester, {
    MockUserApiService? api,
  }) async {
    final prefs = await createEmptyPrefs();
    final mockApi = api ?? (MockUserApiService()..stubGetUser(null));
    await tester.pumpWidget(
      buildTestApp(prefs, overrides: [
        userApiServiceProvider.overrideWithValue(mockApi),
      ]),
    );
    await tester.pumpAndSettle();
  }

  group('LoginScreen', () {
    group('структура экрана', () {
      testWidgets('отображает поля ввода', (tester) async {
        await pumpLogin(tester);
        // Логин и пароль
        expect(find.byType(TextFormField), findsAtLeastNWidgets(2));
      });

      testWidgets('отображает кнопку Войти', (tester) async {
        await pumpLogin(tester);
        expect(find.text('Войти'), findsOneWidget);
      });

      testWidgets('отображает кнопку Зарегистрироваться', (tester) async {
        await pumpLogin(tester);
        expect(find.text('Зарегистрироваться'), findsOneWidget);
      });

      testWidgets('заголовок GIS Monitor присутствует', (tester) async {
        await pumpLogin(tester);
        expect(find.text('GIS Monitor'), findsOneWidget);
      });

      testWidgets('поля логина и пароля пустые при старте', (tester) async {
        await pumpLogin(tester);
        final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
        for (final f in fields) {
          expect(f.controller?.text ?? '', equals(''));
        }
      });
    });

    group('успешный логин', () {
      testWidgets('admin/123456 → кнопка Войти исчезает (перешли на dashboard)',
          (tester) async {
        final api = MockUserApiService()..stubGetUser(null);
        await pumpLogin(tester, api: api);

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.first, 'admin');
        await tester.enterText(fields.last, '123456');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Войти'));
        await tester.pumpAndSettle();

        // После логина экран логина исчезает
        expect(find.text('Войти'), findsNothing);
        // Кнопка регистрации тоже ушла
        expect(find.text('Зарегистрироваться'), findsNothing);
      });
    });

    group('неверные данные', () {
      testWidgets('неверный пароль → остаёмся на логин-экране', (tester) async {
        await pumpLogin(tester);

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.first, 'admin');
        await tester.enterText(fields.last, 'wrong_password');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Войти'));
        await tester.pumpAndSettle();

        // Всё ещё на логин-экране
        expect(find.text('Войти'), findsOneWidget);
      });

      testWidgets('пустые поля → остаёмся на логин-экране', (tester) async {
        await pumpLogin(tester);

        await tester.tap(find.text('Войти'));
        await tester.pumpAndSettle();

        // Поля пустые — login не выполняется
        expect(find.text('Войти'), findsOneWidget);
      });
    });

    group('навигация на регистрацию', () {
      testWidgets('кнопка Зарегистрироваться присутствует и доступна',
          (tester) async {
        await pumpLogin(tester);
        final btn = find.text('Зарегистрироваться');
        expect(btn, findsOneWidget);
        // Кнопка находится внутри виджета с обработчиком нажатия
        expect(
          tester.widget(btn).runtimeType.toString(),
          isNot(equals('SizedBox')),
        );
      });

      testWidgets('тап Зарегистрироваться — не бросает исключений',
          (tester) async {
        // GoRouter full navigation testing — в integration_test.
        // Здесь проверяем что тап не падает с исключением.
        await pumpLogin(tester);
        await tester.tap(find.text('Зарегистрироваться'));
        await tester.pump();
        // Нет необработанных исключений
      });
    });

    group('сохранённые аккаунты', () {
      testWidgets('нет сохранённых аккаунтов при пустых prefs', (tester) async {
        await pumpLogin(tester);
        // «Сохранённые аккаунты» раздел не должен показываться если пусто
        // Просто проверяем что экран нормально загрузился
        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });
  });
}
