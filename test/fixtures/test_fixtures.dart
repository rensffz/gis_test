// test/fixtures/test_fixtures.dart
// Статические тестовые данные и фабрики объектов.
// Используются во всех типах тестов.

import 'package:flutter/material.dart';
import 'package:gis_app/models/app_models.dart';

// ─── AppUser ──────────────────────────────────────────────────

const kTestUser = AppUser(
  id: 'test_u1',
  login: 'testuser',
  firstName: 'Тест',
  lastName: 'Пользователь',
  organization: 'TestOrg',
  email: 'test@test.ru',
  phone: '+7 000 000-00-00',
  passwordHash: 'password123',
);

const kAdminUser = AppUser(
  id: 'u1',
  login: 'admin',
  firstName: 'Иван',
  lastName: 'Петров',
  organization: 'АгроГИС',
  email: 'admin@gis.ru',
  phone: '+7 900 123-45-67',
  passwordHash: '123456',
);

AppUser makeUser({
  String id = 'u_test',
  String login = 'user',
  String firstName = 'Test',
  String lastName = 'User',
  String organization = 'Org',
  String email = 'test@test.ru',
  String phone = '',
  String passwordHash = 'pass',
}) =>
    AppUser(
      id: id,
      login: login,
      firstName: firstName,
      lastName: lastName,
      organization: organization,
      email: email,
      phone: phone,
      passwordHash: passwordHash,
    );

// ─── GisCategory ──────────────────────────────────────────────

const kTestCategory = GisCategory(
  id: 'cat_test',
  name: 'Тестовая категория',
  color: Color(0xFF00D4AA),
  icon: Icons.category_rounded,
);

// ─── GisLayer ─────────────────────────────────────────────────

const kTestLayerArea = GisLayer(
  id: 'layer_area_1',
  name: 'Тестовый полигон',
  type: LayerType.area,
  color: Color(0xFF3D8EF5),
  isVisible: true,
  objectsCount: 5,
);

const kTestLayerPoints = GisLayer(
  id: 'layer_points_1',
  name: 'Тестовые точки',
  type: LayerType.points,
  color: Color(0xFF00D4AA),
  isVisible: true,
  objectsCount: 10,
  tableId: 'tbl_1',
);

const kTestLayerOrtho = GisLayer(
  id: 'layer_ortho_1',
  name: 'Ортофотоплан',
  type: LayerType.orthophoto,
  color: Color(0xFFB06EF5),
  isVisible: false,
  objectsCount: 1,
  fileId: 'file_1',
);

GisLayer makeLayer({
  String id = 'layer_1',
  String name = 'Test Layer',
  LayerType type = LayerType.area,
  bool isVisible = true,
  int objectsCount = 0,
  String? tableId,
  String? fileId,
}) =>
    GisLayer(
      id: id,
      name: name,
      type: type,
      color: type.color,
      isVisible: isVisible,
      objectsCount: objectsCount,
      tableId: tableId,
      fileId: fileId,
    );

// ─── GisObject ────────────────────────────────────────────────

GisObject makeGisObject({
  String id = 'obj_test',
  String name = 'Тестовый объект',
  String description = 'Описание',
  GisCategory? category,
  List<GisLayer>? layers,
  DateTime? updatedAt,
}) =>
    GisObject(
      id: id,
      name: name,
      description: description,
      category: category ?? kTestCategory,
      layers: layers ?? [kTestLayerArea],
      updatedAt: updatedAt ?? DateTime(2024, 3, 20),
      icon: Icons.landscape_rounded,
    );

// ─── GisFile ──────────────────────────────────────────────────

final kTestFileGeotiff = GisFile(
  id: 'file_tif_1',
  name: 'test_ortho.tif',
  type: FileType.geotiff,
  sizeBytes: 10 * 1024 * 1024, // 10 MB
  createdAt: DateTime(2024, 3, 1),
);

final kTestFileDocument = GisFile(
  id: 'file_doc_1',
  name: 'report.pdf',
  type: FileType.document,
  sizeBytes: 500 * 1024, // 500 KB
  createdAt: DateTime(2024, 3, 15),
  description: 'Отчёт',
);

GisFile makeFile({
  String id = 'file_1',
  String name = 'test.file',
  FileType type = FileType.other,
  int sizeBytes = 1024,
  DateTime? createdAt,
  String description = '',
}) =>
    GisFile(
      id: id,
      name: name,
      type: type,
      sizeBytes: sizeBytes,
      createdAt: createdAt ?? DateTime(2024, 1, 1),
      description: description,
    );

// ─── AttributeProperty ────────────────────────────────────────

const kTestPropString = AttributeProperty(
  id: 'prop_str_1',
  name: 'Название поля',
  description: 'Описание',
  measurementUnit: '',
  dataType: DataType.string,
);

const kTestPropInt = AttributeProperty(
  id: 'prop_int_1',
  name: 'Количество',
  description: 'Целое число',
  measurementUnit: 'шт',
  dataType: DataType.integer,
);

const kTestPropDouble = AttributeProperty(
  id: 'prop_dbl_1',
  name: 'Площадь',
  description: 'Вещественное число',
  measurementUnit: 'га',
  dataType: DataType.double_,
);

AttributeProperty makeProperty({
  String id = 'prop_1',
  String name = 'Свойство',
  String description = '',
  String measurementUnit = '',
  DataType dataType = DataType.string,
}) =>
    AttributeProperty(
      id: id,
      name: name,
      description: description,
      measurementUnit: measurementUnit,
      dataType: dataType,
    );

// ─── AttributeTable ───────────────────────────────────────────

AttributeTable makeTable({
  String id = 'tbl_test',
  String name = 'Тестовая таблица',
  String description = 'Описание таблицы',
  List<AttributeProperty>? properties,
  DateTime? updatedAt,
}) =>
    AttributeTable(
      id: id,
      name: name,
      description: description,
      properties: properties ?? [kTestPropString, kTestPropInt],
      updatedAt: updatedAt ?? DateTime(2024, 3, 1),
    );

// ─── MapDemoPoint ─────────────────────────────────────────────

const kTestPoint1 = MapDemoPoint(
  x: 0.25,
  y: 0.35,
  label: 'P-01',
  color: Color(0xFF00D4AA),
);

const kTestPoint2 = MapDemoPoint(
  x: 0.55,
  y: 0.45,
  label: 'P-02',
  color: Color(0xFF00D4AA),
  attributes: {'prop_str_1': 'значение', 'prop_int_1': '42'},
);

MapDemoPoint makePoint({
  double x = 0.5,
  double y = 0.5,
  String label = 'P-00',
  Color color = const Color(0xFF00D4AA),
  Map<String, String> attributes = const {},
}) =>
    MapDemoPoint(x: x, y: y, label: label, color: color, attributes: attributes);

// ─── FileWithObject ───────────────────────────────────────────

FileWithObject makeFileWithObject({
  GisFile? file,
  String objectId = 'obj_1',
  String objectName = 'Объект 1',
  IconData objectIcon = Icons.landscape_rounded,
  Color objectColor = const Color(0xFF00D4AA),
}) =>
    FileWithObject(
      file: file ?? kTestFileDocument,
      objectId: objectId,
      objectName: objectName,
      objectIcon: objectIcon,
      objectColor: objectColor,
    );

// ─── SavedAccount ─────────────────────────────────────────────

const kTestSavedAccount = SavedAccount(
  login: 'testuser',
  displayName: 'Тест Пользователь',
  initials: 'ТП',
);
