# Testing Strategy — GIS Monitor

## 1. Общая стратегия

Система тестирования построена по принципу **Test Pyramid**:
- **Unit tests** (база) — быстрые, изолированные, без Flutter-фреймворка где возможно
- **Widget/Integration tests** (середина) — тестирование UI-потоков с WidgetTester и полным ProviderScope
- **Load/Stress tests** (вершина) — проверка производительности при больших объёмах данных

Главный принцип: **тесты адаптируются к коду, а не код к тестам**. Бизнес-логика, архитектура и структура БД остаются неизменными.

---

## 2. Цели тестирования

| Цель | Метрика |
|------|---------|
| Корректность бизнес-логики | 100% покрытие публичного API репозитория |
| Стабильность auth flow | Все сценарии login/register/logout |
| Целостность данных | CRUD операции над объектами, слоями, файлами, таблицами |
| Производительность | <100ms на операции с 1000+ объектами |
| Регрессии | CI запускает все unit + widget тесты при каждом PR |

---

## 3. Типы тестов

### 3.1 Unit Tests (`test/unit/`)
- Тестируют отдельные классы в изоляции
- Нет Flutter-зависимостей (используют Dart `test`)
- Быстрые: < 1ms на тест
- Покрывают: модели, репозиторий, провайдеры/нотификаторы

### 3.2 Widget/Integration Tests (`test/integration/`)
- Тестируют пользовательские flow через WidgetTester
- Запускают весь граф виджетов с реальным ProviderScope
- Проверяют навигацию, отображение данных, реакцию UI на actions
- Медленнее: 100ms–2s на тест

### 3.3 Load/Stress Tests (`test/load/`)
- Dart unit-тесты с измерением времени выполнения (Stopwatch)
- Генерируют большие датасеты (1000+ объектов, 50+ атрибутов)
- Проверяют: репозиторий, провайдеры, фильтрацию под нагрузкой

### 3.4 Device Integration Tests (`integration_test/`)
- Требуют реального устройства/эмулятора
- Тестируют полный E2E flow на живом приложении

---

## 4. Покрытие по модулям

| Модуль | Unit | Widget | Load |
|--------|------|--------|------|
| `AppUser` / `SavedAccount` | ✅ | — | — |
| `GisObject` / `GisLayer` | ✅ | — | ✅ |
| `GisFile` / `FileWithObject` | ✅ | — | ✅ |
| `AttributeTable` / `AttributeProperty` | ✅ | — | ✅ |
| Enum расширения (LayerType, FileType, DataType) | ✅ | — | — |
| `AppRepository` (auth) | ✅ | — | — |
| `AppRepository` (GIS objects) | ✅ | — | ✅ |
| `AppRepository` (files) | ✅ | — | ✅ |
| `AppRepository` (tables) | ✅ | — | ✅ |
| `AuthNotifier` | ✅ | ✅ | — |
| `LayersNotifier` | ✅ | ✅ | ✅ |
| `AllFilesNotifier` | ✅ | — | ✅ |
| `TablesNotifier` | ✅ | ✅ | ✅ |
| Фильтрация объектов | ✅ | — | ✅ |
| Фильтрация файлов | ✅ | — | — |
| Фильтрация таблиц | ✅ | — | — |
| Auth flow (login/register/logout) | ✅ | ✅ | — |
| Tables flow (create/edit/delete) | ✅ | ✅ | — |
| Map screen (layers, points) | — | ✅ | — |
| Navigation (GoRouter) | — | ✅ | — |

---

## 5. Инструменты

| Инструмент | Назначение |
|-----------|-----------|
| `flutter_test` | WidgetTester, основа widget-тестов |
| `test` (Dart) | Unit-тесты без Flutter-зависимостей |
| `mocktail` | Мокирование AppRepository для нотификаторов |
| `integration_test` | E2E тесты на устройстве |
| `shared_preferences` | `setMockInitialValues({})` для изоляции |
| `flutter_riverpod` | `ProviderContainer` для тестирования нотификаторов |
| `Stopwatch` (Dart) | Измерение производительности в load-тестах |

---

## 6. Структура тестов

```
test/
  unit/
    models/
      app_user_test.dart          # AppUser, SavedAccount, GisCategory
      gis_models_test.dart        # GisObject, GisLayer, MapDemoPoint
      file_models_test.dart       # GisFile, FileWithObject
      table_models_test.dart      # AttributeTable, AttributeProperty
      enums_test.dart             # LayerType, FileType, DataType
    repositories/
      auth_repository_test.dart   # login, register, profile, password
      gis_repository_test.dart    # objects, layers, categories
      files_repository_test.dart  # files, global storage, attach
      tables_repository_test.dart # CRUD таблиц
    providers/
      auth_notifier_test.dart     # AuthNotifier
      layers_notifier_test.dart   # LayersNotifier (family)
      all_files_notifier_test.dart
      tables_notifier_test.dart
      filter_providers_test.dart  # filteredObjects, filteredFiles, filteredTables
  integration/
    auth_flow_test.dart           # login/register/logout UI flow
    tables_flow_test.dart         # CRUD таблиц через UI
  load/
    data_generator.dart           # Генераторы тестовых данных
    repository_load_test.dart     # Репозиторий под нагрузкой
    provider_load_test.dart       # Провайдеры под нагрузкой
  mocks/
    mock_repository.dart          # MockAppRepository (mocktail)
  fixtures/
    test_fixtures.dart            # Тестовые данные и фабрики
  helpers/
    prefs_helper.dart             # SharedPreferences mock setup
    provider_container_helper.dart # ProviderContainer factory
integration_test/
  app_integration_test.dart       # E2E тест на устройстве
```

---

## 7. Подход к мокированию

### Репозиторий (тесты репозитория)
Используем **реальный `AppRepository`** с мок `SharedPreferences`:
```dart
SharedPreferences.setMockInitialValues({});
final prefs = await SharedPreferences.getInstance();
final repo = AppRepository(prefs);
```
Это тестирует реальную логику сериализации/десериализации.

### Репозиторий (тесты нотификаторов)
Используем **`MockAppRepository`** (mocktail) для изоляции нотификатора от хранилища:
```dart
class MockAppRepository extends Mock implements AppRepository {}
final mock = MockAppRepository();
when(() => mock.fetchTables()).thenAnswer((_) async => [...]);
```

### ProviderContainer
```dart
final container = ProviderContainer(overrides: [
  prefsProvider.overrideWithValue(prefs),
]);
addTearDown(container.dispose);
```

### Widget tests
```dart
await tester.pumpWidget(ProviderScope(
  overrides: [prefsProvider.overrideWithValue(prefs)],
  child: const GisApp(),
));
```

---

## 8. Подход к тестовым данным

- **Фикстуры** в `test/fixtures/test_fixtures.dart` — статические константы и фабрики
- **Генераторы** в `test/load/data_generator.dart` — создают N объектов с уникальными ID
- Тестовые данные **не зависят** от seed-данных репозитория
- Каждый тест стартует с чистым состоянием (fresh `AppRepository`)

---

## 9. Offline/sync поведение

Приложение работает в **полностью offline режиме** (нет backend).
- "Offline" = нормальный режим работы
- "Sync" = операции с локальной памятью (in-memory)
- Тесты проверяют сохранность состояния между операциями
- SharedPreferences — единственное персистентное хранилище (auth + saved accounts)
- При hot restart: GIS-данные сбрасываются, auth — восстанавливается

Тестирование восстановления сессии:
```dart
// Имитируем "перезапуск": создаём новый репозиторий с теми же prefs
repo.persistAuth('admin');
final repo2 = AppRepository(prefs); // читает из prefs
expect(repo2.restoredLogin, equals('admin'));
```

---

## 10. Тестирование карты и точек

Карта (`ObjectMapScreen`) — статический `_MapCanvas` без реальных map-тайлов.
- `MapDemoPoint` тестируется как чистая модель (unit)
- `_demoPoints` — изменяемое состояние `StatefulWidget`, тестируется через WidgetTester
- Тестируем: tap на точку (popup), edit (диалог), delete (удаление из списка)
- Zoom/pan — через `GestureDetector`, тестируем изменение `_zoom` и `_pan`

---

## 11. Тестирование таблиц атрибутов

- CRUD `AttributeTable` через `TablesNotifier`
- CRUD `AttributeProperty` внутри таблицы
- Валидация типов данных (`DataType.integer`, `DataType.double_`, `DataType.string`)
- Связь таблицы со слоем (`GisLayer.tableId`)
- Динамические поля в редакторе точки (`_PointEditorDialog`)

---

## 12. Тестирование репозиториев и state management

- Репозиторий: тестируется с реальным `SharedPreferences.setMockInitialValues({})`
- Нотификаторы: тестируются через `ProviderContainer` или с `MockAppRepository`
- `AsyncValue.loading` / `AsyncValue.data` / `AsyncValue.error` — все три состояния
- Семейные провайдеры (`layersProvider.family`) — тестируются с разными `objectId`

---

## 13. Ограничения тестирования

| Область | Ограничение |
|---------|------------|
| Реальная карта | Нет — используется canvas-заглушка |
| Файловая система | Нет реальных файлов — только метаданные |
| Сеть | Нет backend — все данные in-memory |
| SharedPreferences | Используется platform mock (нет реального диска) |
| GoRouter redirect | Требует полного widget дерева для тестирования |
| Параллелизм | Все async операции — Future с фиксированным delay |

---

## 14. Критерии успеха

- ✅ Все unit-тесты проходят: `flutter test test/unit/`
- ✅ Все integration-тесты проходят: `flutter test test/integration/`
- ✅ Load-тесты не превышают лимиты по времени
- ✅ Coverage ≥ 70% для `lib/providers/` и `lib/repositories/`
- ✅ Coverage ≥ 80% для `lib/models/`
- ✅ 0 регрессий в существующем функционале
