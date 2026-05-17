// test/helpers/prefs_helper.dart
// Утилиты для создания SharedPreferences с мок-данными.

import 'package:shared_preferences/shared_preferences.dart';

/// Создаёт SharedPreferences с пустым хранилищем.
/// Используется для изоляции тестов — каждый тест стартует с чистым состоянием.
Future<SharedPreferences> createEmptyPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

/// Создаёт SharedPreferences с предзаполненными данными.
/// Пример: {'repo_auth_login': 'admin', 'repo_users': [...]}
Future<SharedPreferences> createPrefsWithValues(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// Создаёт SharedPreferences с сохранённым auth-логином.
/// Имитирует ситуацию, когда пользователь уже входил в систему.
Future<SharedPreferences> createPrefsWithAuth({
  required String login,
  required String usersJson,
}) async {
  SharedPreferences.setMockInitialValues({
    'repo_auth_login': login,
    'repo_users': [usersJson],
  });
  return SharedPreferences.getInstance();
}
