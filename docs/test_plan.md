# Test Plan — GIS Monitor

## Scope

Тест-план охватывает все уровни тестирования: юнит-тесты (модели, репозиторий, провайдеры),
интеграционные widget-тесты и нагрузочные тесты. E2E device-тесты вынесены в `integration_test/`.

---

## 1. Unit Tests — Models

### 1.1 AppUser

| ID | Название | Тип | Предусловие | Шаги | Ожидаемый результат |
|----|----------|-----|-------------|------|---------------------|
| UM-01 | fullName склеивает имя и фамилию | Unit | — | `AppUser(firstName:'Иван', lastName:'Петров')` | `fullName == 'Иван Петров'` |
| UM-02 | initials — первые буквы | Unit | — | `user.initials` | `'ИП'` |
| UM-03 | copyWith изменяет email | Unit | — | `user.copyWith(email:'new@t.ru')` | новый email, остальное без изменений |
| UM-04 | SavedAccount.fromUser | Unit | — | `SavedAccount.fromUser(user, avatarColor)` | поля совпадают с user |
| UM-05 | GisCategory имеет id, name, color, icon | Unit | — | проверка полей константы | все поля не null |

### 1.2 Enums

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| EN-01 | LayerType.area — label, icon, color | Unit | `LayerType.area.label` | `'Полигоны'` |
| EN-02 | LayerType.points — supportsTable=true | Unit | `LayerType.points.supportsTable` | `true` |
| EN-03 | LayerType.ortho — requiresFile=true | Unit | `LayerType.ortho.requiresFile` | `true` |
| EN-04 | FileType.geotiff.label | Unit | — | `'GeoTIFF'` |
| EN-05 | DataType.string.label | Unit | — | `'Строка'` |
| EN-06 | kAllowedFileTypes не пуст | Unit | — | `kAllowedFileTypes.isNotEmpty` | `true` |

### 1.3 GisLayer / GisObject / MapDemoPoint

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| GM-01 | GisLayer.copyWith меняет isVisible | Unit | `layer.copyWith(isVisible: false)` | `isVisible == false`, id неизменён |
| GM-02 | GisObject.layerCount | Unit | `obj.layerCount == 3` | `true` |
| GM-03 | MapDemoPoint.copyWith меняет label | Unit | `point.copyWith(label: 'X')` | `label == 'X'` |
| GM-04 | MapDemoPoint с пустыми attributes | Unit | `attributes: {}` | не бросает исключение |

### 1.4 GisFile / FileWithObject

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| FM-01 | sizeLabel — байты | Unit | `sizeBytes: 500` | `'500 Б'` |
| FM-02 | sizeLabel — KB | Unit | `sizeBytes: 2048` | `'2.0 КБ'` |
| FM-03 | sizeLabel — MB | Unit | `sizeBytes: 1048576` | `'1.0 МБ'` |
| FM-04 | sizeLabel — 0 байт | Unit | `sizeBytes: 0` | `'0 Б'` |

### 1.5 AttributeTable / AttributeProperty

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| TM-01 | propertyCount == properties.length | Unit | таблица с 3 свойствами | `propertyCount == 3` |
| TM-02 | AttributeProperty.copyWith меняет name | Unit | `prop.copyWith(name: 'X')` | `name == 'X'` |
| TM-03 | required по умолчанию = false | Unit | `makeProperty()` | `required == false` |

---

## 2. Unit Tests — Repository

### 2.1 Auth

| ID | Название | Тип | Предусловие | Шаги | Ожидаемый результат |
|----|----------|-----|-------------|------|---------------------|
| RA-01 | login — admin с верным паролем | Unit | seed-данные | `repo.login('admin','123456')` | возвращает AppUser |
| RA-02 | login — неверный пароль | Unit | seed-данные | `repo.login('admin','wrong')` | `null` |
| RA-03 | login — несуществующий логин | Unit | seed-данные | `repo.login('ghost','pass')` | `null` |
| RA-04 | login — case-sensitive | Unit | seed-данные | `repo.login('Admin','123456')` | `null` |
| RA-05 | register — создаёт пользователя | Unit | пустые prefs | register + login | login возвращает user |
| RA-06 | register — дублирующийся логин бросает | Unit | уже есть логин | повторный register | кидает `Exception` |
| RA-07 | isLoginTaken — true для существующего | Unit | — | `isLoginTaken('admin')` | `true` |
| RA-08 | isLoginTaken — excludeId исключает себя | Unit | — | `isLoginTaken('admin', excludeId: adminId)` | `false` |
| RA-09 | savedAccounts — пустой список изначально | Unit | — | `getSavedAccounts()` | `[]` |
| RA-10 | saveAccount / getSavedAccounts | Unit | — | save → get | содержит account |
| RA-11 | removeSavedAccount | Unit | — | save → remove → get | пустой список |
| RA-12 | auth persistence — login сохраняется | Unit | — | login → новый repo | `restoredLogin` возвращает login |

### 2.2 GIS Objects

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| RG-01 | fetchObjects — 6 seed-объектов | Unit | — | `fetchObjects()` | `length == 6` |
| RG-02 | addObject — вставляется в начало | Unit | — | `addObject(obj)`, fetch | `all.first.id == obj.id` |
| RG-03 | fetchObjects — immutable список | Unit | — | два вызова fetch | разные экземпляры List |

### 2.3 Layers

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| RL-01 | fetchLayers — кэш инициализируется | Unit | — | первый fetch | не бросает |
| RL-02 | fetchLayers — разные objectId независимы | Unit | — | fetch obj_1, fetch obj_2 | разные списки |
| RL-03 | updateLayerVisibility | Unit | — | set false, fetch | `isVisible == false` |
| RL-04 | deleteLayer | Unit | — | delete l1, fetch | l1 отсутствует |
| RL-05 | addLayer | Unit | — | add, fetch | новый слой в списке |

### 2.4 Files

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| RF-01 | addGlobalFile / getGlobalFiles | Unit | — | add, get | файл в списке |
| RF-02 | addFileToObject — нет дублей | Unit | — | add дважды | `count == 1` |
| RF-03 | fetchAllFiles — глобальные сначала | Unit | — | global + obj files | global идёт первым |
| RF-04 | deleteFiles — batch | Unit | — | delete {id1, id2} | оба отсутствуют |

### 2.5 Tables

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| RT-01 | fetchTables — 4 seed-таблицы | Unit | — | `fetchTables()` | `length == 4` |
| RT-02 | createTable — вставляется в начало | Unit | — | create, fetch | `all.first.id == t.id` |
| RT-03 | updateTable — обновляет updatedAt | Unit | — | update | `updatedAt > createdAt` |
| RT-04 | deleteTable — удаляет по id | Unit | — | delete, fetch | id отсутствует |

---

## 3. Unit Tests — Providers

### 3.1 Auth Notifier

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| PA-01 | restore — неавторизованный | Unit | пустые prefs | `restore()` | `isLoggedIn == false` |
| PA-02 | login — успешный | Unit | — | `login('admin','123456')` | `isLoggedIn == true` |
| PA-03 | login — неверный | Unit | — | `login('admin','wrong')` | `isLoggedIn == false` |
| PA-04 | register — дублирующийся логин | Unit | — | register twice | кидает исключение |
| PA-05 | logout | Unit | — | login → logout | `isLoggedIn == false` |
| PA-06 | updateProfile | Unit | — | login → update | имя изменилось |
| PA-07 | changePassword | Unit | — | login → change → re-login | старый пароль не работает |
| PA-08 | quickLogin через SavedAccount | Unit | — | save → quickLogin | `isLoggedIn == true` |

### 3.2 Layers Notifier

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| PL-01 | начальное состояние — AsyncLoading | Unit | — | `read(provider)` | `isA<AsyncLoading>()` |
| PL-02 | после инициализации — AsyncData | Unit | — | await load | `hasLength(3)` |
| PL-03 | разные objectId — независимые | Unit | — | obj_1 и obj_2 | разные списки |
| PL-04 | toggleVisibility меняет флаг | Unit | — | toggle l1 | `isVisible` инвертирован |
| PL-05 | toggleVisibility не меняет другие | Unit | — | toggle l1 | l2, l3 без изменений |
| PL-06 | toggleVisibility в loading — noop | Unit | не ждём загрузки | toggle | `verifyNever(repo.update)` |
| PL-07 | deleteLayer убирает слой | Unit | — | delete l1 | l1 отсутствует |
| PL-08 | addLayer добавляет в конец | Unit | — | add | `last.id == newId` |
| PL-09 | ошибка загрузки — AsyncError | Unit | mock throws | await | `isA<AsyncError>()` |

### 3.3 Tables Notifier

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| PT-01 | create вставляет в начало | Unit | — | create | `first.id == newId` |
| PT-02 | update меняет в списке | Unit | — | update tbl_1 | `name == 'Обновлённая'` |
| PT-03 | delete — оптимистичное обновление | Unit | mock delay | delete, проверяем до await | id уже отсутствует |
| PT-04 | delete — откат при ошибке | Unit | mock throws | try delete | id вернулся |
| PT-05 | reload перезагружает данные | Unit | — | reload → новый мок | новая длина |

### 3.4 All Files Notifier

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| PF-01 | addGlobal — файл в начале | Unit | — | addGlobal | `first.id == newId` |
| PF-02 | addGlobal в loading — noop | Unit | не ждём загрузки | addGlobal | state == null |
| PF-03 | addToObject — файл появляется | Unit | — | addToObject | id присутствует |
| PF-04 | delete убирает файл | Unit | — | delete {id} | id отсутствует |
| PF-05 | delete нескольких | Unit | — | delete {id1, id2} | оба отсутствуют |
| PF-06 | globalFilesProvider — только без objectId | Unit | — | seed global + obj | только global |

### 3.5 Filter Providers

| ID | Название | Тип | Шаги | Ожидаемый результат |
|----|----------|-----|------|---------------------|
| FF-01 | без фильтров — все объекты | Unit | 3 объекта | `filteredObjects` | `length == 3` |
| FF-02 | поиск по имени (case-insensitive) | Unit | — | search = 'пшен' | `length == 2` |
| FF-03 | поиск по описанию | Unit | — | search = 'вода' | `length == 1` |
| FF-04 | trim пробелов | Unit | — | search = '  пшен  ' | `length == 2` |
| FF-05 | нет совпадений | Unit | — | search = 'xyz' | пусто |
| FF-06 | фильтр по категории | Unit | — | cat = 'cat_1' | только cat_1 |
| FF-07 | category + search | Unit | — | cat_1 + 'Поле' | `length == 1` |
| FF-08 | filteredTablesProvider по описанию | Unit | — | search = 'агро' | `length == 1` |
| FF-09 | filteredFilesProvider по objectName | Unit | — | search = 'водо' | `length == 1` |

---

## 4. Integration Tests — Widget

### 4.1 Auth Flow

| ID | Название | Тип | Предусловие | Шаги | Ожидаемый результат |
|----|----------|-----|-------------|------|---------------------|
| IA-01 | экран логина для неавторизованного | Widget | пустые prefs | pumpApp | `find.text('Войдите в систему')` |
| IA-02 | поля логин и пароль | Widget | — | pumpApp | `findsNWidgets(2)` TextFormField |
| IA-03 | кнопка Войти | Widget | — | pumpApp | `findsOneWidget` |
| IA-04 | кнопка Зарегистрироваться | Widget | — | pumpApp | `findsOneWidget` |
| IA-05 | валидация пустого логина | Widget | — | tap Войти | `find.text('Введите логин')` |
| IA-06 | валидация короткого пароля | Widget | — | enter 2 chars, tap Войти | `find.text('Минимум 4 символа')` |
| IA-07 | успешный логин → dashboard | Widget | — | admin/123456, tap Войти | 'Войдите в систему' исчез |
| IA-08 | неверный пароль → ошибка | Widget | — | admin/wrong, tap Войти | SnackBar 'Неверный логин или пароль' |
| IA-09 | Зарегистрироваться → Step1 | Widget | — | ensureVisible, tap | 'Придумайте пароль' |
| IA-10 | Step1 показывает поля пароля | Widget | — | перейти на Step1 | TextFormField + '6 символов' |
| IA-11 | saved accounts пусты | Widget | пустые prefs | pumpApp | нет 'Сохранённые аккаунты' |
| IA-12 | кнопка смены темы | Widget | — | pumpApp | `findsWidgets(IconButton)` |
| IA-13 | авторизованный → сразу dashboard | Widget | prefs с auth_login | pumpApp | нет 'Войдите в систему' |

### 4.2 Tables Screen

| ID | Название | Тип | Предусловие | Шаги | Ожидаемый результат |
|----|----------|-----|-------------|------|---------------------|
| IT-01 | список таблиц | Widget | 2 таблицы в mock | pumpWidget + settle | оба имени видны |
| IT-02 | количество свойств | Widget | tbl_1 с 2 props | pumpWidget + settle | содержит '2' |
| IT-03 | поле поиска | Widget | — | settle | `find.byType(TextField)` |
| IT-04 | фильтрация по поиску | Widget | — | enterText 'климат' | только 1я таблица |
| IT-05 | очистка поиска | Widget | — | enter 'климат', clear | обе таблицы |
| IT-06 | skeleton при загрузке | Widget | Completer mock | pump(50ms) | `find.byType(SkeletonBox)` |
| IT-07 | сообщение об ошибке | Widget | mock throws | settle | `find.textContaining('error')` |
| IT-08 | диалог удаления | Widget | mock с deleteTable | tap delete icon | 'Удалить таблицу?' |
| IT-09 | embedded=true без AppBar | Widget | Scaffold обёртка | settle | нет 'Таблицы атрибутов' |

---

## 5. Load Tests — Repository

| ID | Название | Тип | Параметры | Ожидаемый результат |
|----|----------|-----|-----------|---------------------|
| LR-01 | fetchObjects seed | Load | — | length == 6 |
| LR-02 | addObject × 10 | Load | 10 объектов | length ≥ 10 |
| LR-03 | первый объект в начале | Load | — | `all.first.id == obj.id` |
| LR-04 | 20 объектов корректно | Load | timeout 30s | length == 26 |
| LR-05 | fetchLayers для 5 объектов | Load | каждый 4 слоя | length == 4 для каждого |
| LR-06 | addLayer × 10 к obj_1 | Load | — | length ≥ 10 |
| LR-07 | toggleVisibility × 10 | Load | — | length сохраняется |
| LR-08 | deleteLayer не лишние | Load | — | length == before-1 |
| LR-09 | addGlobalFile × 50 | Load | sync | length + 50, time < 500ms |
| LR-10 | getGlobalFiles × 100 | Load | sync | time < 100ms |
| LR-11 | deleteFiles × 100 | Load | sync | time < 200ms |
| LR-12 | attachFileToObject × 30 | Load | sync | time < 200ms |
| LR-13 | addFileToObject без дублей | Load | add × 2 | count == 1 |
| LR-14 | createTable × 10 | Load | — | length == 14 |
| LR-15 | 50 свойств — propertyCount | Load | — | == 50 |
| LR-16 | updateTable × 4 seed | Load | — | all.every name ends 'UPDATED' |
| LR-17 | deleteTable × 4 | Load | — | пусто |
| LR-18 | register × 10 | Load | — | все могут войти |
| LR-19 | isLoginTaken × 200 | Load | sync | time < 100ms |
| LR-20 | getSavedAccounts × 100 | Load | sync | time < 50ms |

---

## 6. Load Tests — Providers

| ID | Название | Тип | Параметры | Ожидаемый результат |
|----|----------|-----|-----------|---------------------|
| LP-01 | фильтрация 1000 объектов | Load | MockRepo | time < 50ms |
| LP-02 | фильтрация по категории 1000 | Load | — | time < 20ms |
| LP-03 | 1000 объектов загружаются | Load | — | length == 1000 |
| LP-04 | сброс фильтра 1000 | Load | — | length == 1000 |
| LP-05 | фильтрация 500 таблиц | Load | — | time < 20ms |
| LP-06 | фильтрация 500 файлов | Load | — | time < 20ms |
| LP-07 | toggleVisibility × 100 | Load | — | time < 2000ms |
| LP-08 | 20 слоёв в LayersNotifier | Load | — | length == 20 |
| LP-09 | create × 100 таблиц | Load | — | length == 100 |
| LP-10 | addGlobal × 100 | Load | — | length > 10, time < 500ms |
| LP-11 | delete × 50 из 100 | Load | — | length == 50 |
| LP-12 | generatePoints(1000) | Load | sync | time < 100ms |
| LP-13 | copyWith × 1000 точек | Load | sync | time < 50ms |
| LP-14 | таблица с 100 свойствами | Load | sync | propertyCount == 100 |
| LP-15 | copyWith × 1000 таблиц | Load | sync | time < 100ms |

---

## Исключения и ограничения

- E2E device-тесты (login → dashboard на реальном устройстве) описаны в `integration_test/` и не входят в `flutter test`.
- Тесты слоёв карты и рендеринга GeoTIFF не реализованы (требуют real device / GL surface).
- `AppRepository` имеет встроенные задержки 600ms / 250ms — тесты репозитория не проверяют timing async-операций.
