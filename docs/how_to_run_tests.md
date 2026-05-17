# How to Run Tests — GIS Monitor

## Требования

- Flutter SDK ≥ 3.19 (Dart ≥ 3.3)
- `flutter pub get` — установить зависимости

```bash
flutter pub get
```

---

## Запуск всего набора тестов

```bash
flutter test test/
```

Вывод: `+304: All tests passed!`

---

## Запуск по группам

### Юнит-тесты — модели

```bash
flutter test test/unit/models/
```

Файлы: `app_user_test.dart`, `enums_test.dart`, `gis_models_test.dart`,
`file_models_test.dart`, `table_models_test.dart`

### Юнит-тесты — репозиторий

```bash
flutter test test/unit/repositories/
```

Файлы: `auth_repository_test.dart`, `gis_repository_test.dart`,
`files_repository_test.dart`, `tables_repository_test.dart`

> **Примечание:** тесты репозитория используют реальный `AppRepository`
> с `SharedPreferences.setMockInitialValues({})`. Каждый тест изолирован.

### Юнит-тесты — провайдеры

```bash
flutter test test/unit/providers/
```

Файлы: `auth_notifier_test.dart`, `layers_notifier_test.dart`,
`tables_notifier_test.dart`, `all_files_notifier_test.dart`,
`filter_providers_test.dart`

### Интеграционные тесты (Widget)

```bash
flutter test test/integration/
```

Файлы: `auth_flow_test.dart`, `tables_flow_test.dart`

Запускают полное дерево виджетов через `WidgetTester`. Не требуют устройства.

### Нагрузочные тесты

```bash
flutter test test/load/
```

Файлы: `repository_load_test.dart`, `provider_load_test.dart`

> **Примечание:** `repository_load_test.dart` медленнее остальных (~35–45 с),
> так как `AppRepository` имеет встроенные задержки 600ms / 250ms.
> Тесты провайдеров (`provider_load_test.dart`) используют `MockAppRepository`
> и выполняются за ≤ 1 с.

---

## Запуск одного файла

```bash
flutter test test/unit/providers/tables_notifier_test.dart
```

## Запуск по имени теста

```bash
flutter test --name "оптимистичное обновление"
```

## Запуск по группе

```bash
flutter test --name "TablesNotifier delete"
```

---

## Покрытие кода

### Сгенерировать отчёт покрытия

```bash
flutter test test/ --coverage
```

Результат сохраняется в `coverage/lcov.info`.

### HTML-отчёт (требует lcov)

```bash
# macOS
brew install lcov
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Исключить generated-файлы из покрытия

```bash
flutter test test/ --coverage && \
  lcov --remove coverage/lcov.info '*.g.dart' '*.freezed.dart' \
       -o coverage/lcov_filtered.info && \
  genhtml coverage/lcov_filtered.info -o coverage/html
```

---

## E2E тесты на устройстве

Требуют подключённого устройства или запущенного эмулятора.

```bash
# Запустить на конкретном устройстве
flutter test integration_test/app_integration_test.dart \
  -d <device-id>

# Посмотреть доступные устройства
flutter devices
```

E2E тесты находятся в `integration_test/` (не в `test/`) и используют
`IntegrationTestWidgetsFlutterBinding`. Они не включены в `flutter test test/`.

---

## Структура папок

```
test/
├── helpers/
│   ├── prefs_helper.dart           # createEmptyPrefs(), createPrefsWithValues()
│   └── provider_container_helper.dart # buildTestApp(), buildIsolatedWidget(), awaitNotifierData()
├── fixtures/
│   └── test_fixtures.dart          # константы и фабрики тестовых данных
├── mocks/
│   └── mock_repository.dart        # MockAppRepository + registerMockFallbacks()
├── unit/
│   ├── models/                     # тесты моделей
│   ├── repositories/               # тесты AppRepository
│   └── providers/                  # тесты Riverpod-нотификаторов
├── integration/
│   ├── auth_flow_test.dart         # widget-тесты авторизации
│   └── tables_flow_test.dart       # widget-тесты экрана таблиц
└── load/
    ├── data_generator.dart         # генераторы данных и measureSyncMs()
    ├── repository_load_test.dart   # нагрузка на AppRepository
    └── provider_load_test.dart     # нагрузка на провайдеры (MockAppRepository)

integration_test/
└── app_integration_test.dart       # E2E тесты на устройстве
```

---

## CI — пример GitHub Actions

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.x'
      - run: flutter pub get
      - run: flutter test test/ --coverage
      - uses: codecov/codecov-action@v4
        with:
          files: coverage/lcov.info
```

---

## Известные ограничения

- `repository_load_test.dart` занимает 35–45 секунд из-за встроенных задержек `AppRepository` — это нормально.
- Тесты map-рендеринга (GeoTIFF, слои на карте) не реализованы — требуют GL surface.
- Нотификатор `AuthNotifier` тестируется через реальный `AppRepository` (не mock), т.к. тестирует сериализацию SharedPreferences.
