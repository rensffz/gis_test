// test/mocks/mock_repository.dart
// MockAppRepository на основе mocktail.
// Используется в тестах нотификаторов для изоляции от SharedPreferences.

import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gis_app/repositories/app_repository.dart';
import 'package:gis_app/models/app_models.dart';

/// Мок-репозиторий для тестирования нотификаторов в изоляции.
class MockAppRepository extends Mock implements AppRepository {}

/// Регистрирует fallback-значения для mocktail.
/// Вызывать один раз в setUpAll() тест-файла.
void registerMockFallbacks() {
  registerFallbackValue(const AppUser(
    id: 'fb_id', login: 'fb_login', firstName: 'fb', lastName: 'fb',
    organization: 'fb', email: 'fb@fb.com',
  ));
  registerFallbackValue(const GisLayer(
    id: 'fb_layer', name: 'fb', type: LayerType.area,
    color: Color(0xFF00D4AA), isVisible: true, objectsCount: 0,
  ));
  registerFallbackValue(GisFile(
    id: 'fb_file', name: 'fb.file', type: FileType.other,
    sizeBytes: 0, createdAt: DateTime(2024),
  ));
  registerFallbackValue(AttributeTable(
    id: 'fb_tbl', name: 'fb', description: 'fb',
    properties: const [], updatedAt: DateTime(2024),
  ));
}

// Хелперы для стандартных стабов

extension MockRepoAuthStubs on MockAppRepository {
  void stubRestoredLogin(String? login) {
    when(() => restoredLogin).thenReturn(login);
  }

  void stubGetUserByLogin(String login, AppUser? user) {
    when(() => getUserByLogin(login)).thenReturn(user);
  }

  void stubLogin(String login, String pass, AppUser? result) {
    when(() => this.login(login, pass)).thenAnswer((_) async => result);
  }

  void stubRegister(AppUser result) {
    when(() => register(
          login: any(named: 'login'),
          password: any(named: 'password'),
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
          organization: any(named: 'organization'),
          email: any(named: 'email'),
        )).thenAnswer((_) async => result);
  }

  void stubIsLoginTaken(bool taken) {
    when(() => isLoginTaken(any(), excludeId: any(named: 'excludeId')))
        .thenReturn(taken);
  }

  void stubSaveAccount() {
    when(() => saveAccount(any())).thenReturn(null);
  }

  void stubPersistAuth() {
    when(() => persistAuth(any())).thenReturn(null);
  }

  void stubClearAuth() {
    when(() => clearAuth()).thenReturn(null);
  }

  void stubGetSavedAccounts(List<SavedAccount> accounts) {
    when(() => getSavedAccounts()).thenReturn(accounts);
  }
}

extension MockRepoLayersStubs on MockAppRepository {
  void stubFetchLayers(String objectId, List<GisLayer> layers) {
    when(() => fetchLayers(objectId)).thenAnswer((_) async => layers);
  }

  void stubUpdateLayerVisibility() {
    when(() => updateLayerVisibility(any(), any(), any()))
        .thenAnswer((_) async {});
  }

  void stubDeleteLayer() {
    when(() => deleteLayer(any(), any())).thenAnswer((_) async {});
  }

  void stubAddLayer() {
    when(() => addLayer(any(), any())).thenAnswer((_) async {});
  }
}

extension MockRepoTablesStubs on MockAppRepository {
  void stubFetchTables(List<AttributeTable> tables) {
    when(() => fetchTables()).thenAnswer((_) async => tables);
  }

  void stubCreateTable(AttributeTable result) {
    when(() => createTable(any())).thenAnswer((_) async => result);
  }

  void stubUpdateTable(AttributeTable result) {
    when(() => updateTable(any())).thenAnswer((_) async => result);
  }

  void stubDeleteTable() {
    when(() => deleteTable(any())).thenAnswer((_) async {});
  }
}

extension MockRepoFilesStubs on MockAppRepository {
  void stubFetchAllFiles(List<FileWithObject> files) {
    when(() => fetchAllFiles()).thenAnswer((_) async => files);
  }

  void stubAddGlobalFile(FileWithObject result) {
    when(() => addGlobalFile(any())).thenReturn(result);
  }

  void stubAddFileToObject(FileWithObject result) {
    when(() => addFileToObject(any(), any())).thenReturn(result);
  }

  void stubDeleteFiles() {
    when(() => deleteFiles(any())).thenReturn(null);
  }
}

extension MockRepoObjectsStubs on MockAppRepository {
  void stubFetchObjects(List<GisObject> objects) {
    when(() => fetchObjects()).thenAnswer((_) async => objects);
  }

  void stubAddObject() {
    when(() => addObject(any())).thenAnswer((_) async {});
  }

  void stubUpdateObject() {
    when(() => updateObject(any())).thenAnswer((_) async {});
  }

  void stubDeleteObject() {
    when(() => deleteObject(any())).thenAnswer((_) async {});
  }
}

extension MockRepoGisStubs on MockAppRepository {
  void stubFetchCategories(List<GisCategory> cats) {
    when(() => fetchCategories()).thenAnswer((_) async => cats);
  }
}
