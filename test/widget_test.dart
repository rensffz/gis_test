// test/widget_test.dart
// Базовый smoke-тест: приложение запускается и показывает экран логина.
// Заменяет шаблонный тест из Flutter template.

import 'package:flutter_test/flutter_test.dart';
import 'helpers/prefs_helper.dart';
import 'helpers/provider_container_helper.dart';

void main() {
  testWidgets('Приложение запускается и показывает экран логина', (tester) async {
    final prefs = await createEmptyPrefs();
    await tester.pumpWidget(buildTestApp(prefs));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('GIS Monitor'), findsOneWidget);
  });
}
