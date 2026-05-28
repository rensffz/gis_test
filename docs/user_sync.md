# User Sync Architecture

  ## 1. Архитектура

  UI
  ↓
  AuthNotifier (Riverpod StateNotifier)
       ↓                    ↓
  AppRepository         UserApiService
  (SharedPreferences)   (Dio → localhost:3000)
       ↓
  userSyncStatusProvider (StateProvider)

  ## 2. Data Flow

  - `AppRepository` — только локальное хранилище (SharedPreferences). Без сетевых запросов.
  - `UserApiService` — только сетевой слой. Без бизнес-логики.
  - `AuthNotifier` — координирует: сначала обновляет локальное состояние, затем запускает фоновую
  синхронизацию.

  ## 3. REST Layer

  **Base URL:** `http://localhost:3000`

  | Метод | Endpoint | Когда вызывается |
  |---|---|---|
  | GET | /user?id={id} | Старт + восстановление сессии, login, quickLogin |
  | POST | /user | После регистрации |
  | PUT | /user | После обновления профиля |
  | PATCH | /user | После смены пароля |

  ### Пример JSON

  **Request GET /user?id=u1**
  ```json
  // Response 200
  {
    "id": "u1",
    "login": "admin",
    "firstName": "Иван",
    "lastName": "Петров",
    "organization": "АгроГИС",
    "email": "admin@gis.ru",
    "phone": "+7 900 123-45-67"
  }

  Request POST /user (регистрация)
  {
    "id": "u1697000000000",
    "login": "newuser",
    "firstName": "Мария",
    "lastName": "Иванова",
    "organization": "ГИС Лаб",
    "email": "maria@gis.ru",
    "phone": "",
    "password": "secret123"
  }

  Request PUT /user (обновление профиля)
  {
    "id": "u1",
    "login": "admin",
    "firstName": "Иван",
    "lastName": "Сидоров",
    "organization": "АгроГИС",
    "email": "admin@gis.ru",
    "phone": "+7 900 000-00-00"
  }

  Request PATCH /user (смена пароля)
  {
    "login": "admin",
    "currentPassword": "123456",
    "newPassword": "newpass"
  }
