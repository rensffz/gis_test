// lib/repositories/app_repository.dart
// Mock repository. All GIS/table/file data is in-memory.
// Auth and saved accounts are persisted to SharedPreferences so they
// survive full cold restarts.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import '../core/app_theme.dart';

// ─── Seed data ────────────────────────────────────────────────

final _categories = [
  const GisCategory(id: 'cat_1', name: 'Сельхозугодья',  color: AppColors.layerPoint,    icon: Icons.grass_rounded),
  const GisCategory(id: 'cat_2', name: 'Водные объекты', color: AppColors.layerPolygon,  icon: Icons.water_rounded),
  const GisCategory(id: 'cat_3', name: 'Дороги',         color: AppColors.layerPolyline, icon: Icons.route_rounded),
  const GisCategory(id: 'cat_4', name: 'Строения',       color: AppColors.layerRaster,   icon: Icons.warehouse_rounded),
  const GisCategory(id: 'cat_5', name: 'Лесной фонд',    color: AppColors.layerHeatmap,  icon: Icons.park_rounded),
];

List<GisLayer> _layers(String pfx) => [
  GisLayer(id: '${pfx}_l1', name: 'Границы участка',  type: LayerType.area,       color: AppColors.layerPolygon, isVisible: true,  objectsCount: 3),
  GisLayer(id: '${pfx}_l2', name: 'Точки измерений',  type: LayerType.points,     color: AppColors.layerPoint,   isVisible: true,  objectsCount: 47, tableId: 'tbl_1'),
  GisLayer(id: '${pfx}_l3', name: 'Ортофотоплан',     type: LayerType.orthophoto, color: AppColors.layerRaster,  isVisible: true,  objectsCount: 1,  fileId: 'g_f1'),
  GisLayer(id: '${pfx}_l4', name: 'Контур поля',      type: LayerType.area,       color: AppColors.layerPolygon, isVisible: true,  objectsCount: 12),
];

List<GisFile> _files(String pfx) => [
  GisFile(id: '${pfx}_f1', name: 'orthophoto_2024.tif', type: FileType.geotiff,  sizeBytes: 184320000, createdAt: DateTime(2024, 3, 12)),
  GisFile(id: '${pfx}_f2', name: 'survey_flight.mp4',   type: FileType.video,    sizeBytes: 512000000, createdAt: DateTime(2024, 3, 12)),
  GisFile(id: '${pfx}_f3', name: 'field_report.pdf',    type: FileType.document, sizeBytes:   2048000, createdAt: DateTime(2024, 3, 15)),
  GisFile(id: '${pfx}_f4', name: 'photo_001.jpg',       type: FileType.image,    sizeBytes:   4200000, createdAt: DateTime(2024, 3, 15)),
];

// Global file storage — not bound to any object.
final _seedGlobalFiles = [
  GisFile(id: 'g_f1', name: 'regional_ortho_2024.tif', type: FileType.geotiff,    sizeBytes: 95100000, createdAt: DateTime(2024, 1, 10)),
  GisFile(id: 'g_f2', name: 'elevation_dem.las',        type: FileType.pointcloud, sizeBytes: 34500000, createdAt: DateTime(2024, 1, 20)),
  GisFile(id: 'g_f3', name: 'work_plan_q1.pdf',         type: FileType.document,   sizeBytes:  1200000, createdAt: DateTime(2024, 2,  5)),
];

final _seedObjects = [
  GisObject(id: 'obj_1', name: 'Поле №12 — Пшеница', description: 'Озимая пшеница, 48 га. Мониторинг вегетации 2024.', category: _categories[0], layers: _layers('obj_1'), updatedAt: DateTime(2024, 3, 20), icon: Icons.grass_rounded),
  GisObject(id: 'obj_2', name: 'Водохранилище Южное', description: 'Оросительный резервуар. Объём 120 000 м³.', category: _categories[1], layers: _layers('obj_2').take(3).toList(), updatedAt: DateTime(2024, 3, 18), icon: Icons.water_rounded),
  GisObject(id: 'obj_3', name: 'Дорога Р-217 (участок)', description: 'Грунтовая дорога, протяжённость 4.2 км.', category: _categories[2], layers: _layers('obj_3').take(2).toList(), updatedAt: DateTime(2024, 3, 10), icon: Icons.route_rounded),
  GisObject(id: 'obj_4', name: 'Ферма "Зарево"', description: 'Животноводческий комплекс. Площадь 6.8 га.', category: _categories[3], layers: _layers('obj_4'), updatedAt: DateTime(2024, 3, 22), icon: Icons.warehouse_rounded),
  GisObject(id: 'obj_5', name: 'Лесополоса №7', description: 'Защитная лесополоса. Береза, дуб. Длина 1.8 км.', category: _categories[4], layers: _layers('obj_5').take(3).toList(), updatedAt: DateTime(2024, 3, 5), icon: Icons.park_rounded),
  GisObject(id: 'obj_6', name: 'Поле №8 — Подсолнечник', description: 'Подсолнечник, 63 га. Урожайность 2023: 24 ц/га.', category: _categories[0], layers: _layers('obj_6').take(3).toList(), updatedAt: DateTime(2024, 2, 28), icon: Icons.brightness_7_rounded),
];

final _seedTables = [
  AttributeTable(id: 'tbl_1', name: 'Климатические показатели', description: 'Метеорологические измерения для полевых объектов', updatedAt: DateTime(2024, 3, 20), properties: const [
    AttributeProperty(id: 'p1_1', name: 'Температура воздуха', description: 'Среднесуточная t° на высоте 2м', measurementUnit: '°C'),
    AttributeProperty(id: 'p1_2', name: 'Влажность воздуха',   description: 'Относительная влажность',         measurementUnit: '%'),
    AttributeProperty(id: 'p1_3', name: 'Скорость ветра',      description: 'Среднесуточная скорость',          measurementUnit: 'м/с'),
    AttributeProperty(id: 'p1_4', name: 'Осадки',              description: 'Количество осадков за период',     measurementUnit: 'мм'),
  ]),
  AttributeTable(id: 'tbl_2', name: 'Почвенные характеристики', description: 'Агрохимические и физические свойства почвы', updatedAt: DateTime(2024, 3, 15), properties: const [
    AttributeProperty(id: 'p2_1', name: 'pH почвы',              description: 'Кислотность почвенного раствора', measurementUnit: 'ед.'),
    AttributeProperty(id: 'p2_2', name: 'Органическое вещество', description: 'Содержание гумуса',               measurementUnit: '%'),
    AttributeProperty(id: 'p2_3', name: 'Азот',                  description: 'Содержание нитратного азота',     measurementUnit: 'мг/кг'),
  ]),
  AttributeTable(id: 'tbl_3', name: 'Геодезические данные', description: 'Высотные и координатные характеристики', updatedAt: DateTime(2024, 3, 10), properties: const [
    AttributeProperty(id: 'p3_1', name: 'Высота над уровнем моря', description: 'Абсолютная высота', measurementUnit: 'м'),
    AttributeProperty(id: 'p3_2', name: 'Уклон поверхности',       description: 'Угол наклона рельефа', measurementUnit: '°'),
    AttributeProperty(id: 'p3_3', name: 'Площадь участка',         description: 'Геодезическая площадь', measurementUnit: 'га'),
  ]),
  AttributeTable(id: 'tbl_4', name: 'БПЛА-съёмка', description: 'Технические параметры аэрофотосъёмки', updatedAt: DateTime(2024, 2, 28), properties: const [
    AttributeProperty(id: 'p4_1', name: 'Высота полёта', description: 'Высота съёмки над рельефом', measurementUnit: 'м'),
    AttributeProperty(id: 'p4_2', name: 'GSD',           description: 'Ground Sample Distance',     measurementUnit: 'см/пкс'),
  ]),
];

// ─── SharedPreferences keys ───────────────────────────────────
const _kUsers      = 'repo_users';
const _kSaved      = 'repo_saved_accounts';
const _kAuthLogin  = 'repo_auth_login';
const _kSyncStatus = 'repo_sync_status';


// ─── Encode / decode helpers ──────────────────────────────────

String _encodeUser(AppUser u) => jsonEncode({
  'id': u.id, 'login': u.login, 'firstName': u.firstName,
  'lastName': u.lastName, 'organization': u.organization,
  'email': u.email, 'phone': u.phone, 'passwordHash': u.passwordHash,
});

AppUser _decodeUser(String s) {
  final m = jsonDecode(s) as Map<String, dynamic>;
  return AppUser(
    id: m['id'] as String, login: m['login'] as String,
    firstName: m['firstName'] as String, lastName: m['lastName'] as String,
    organization: m['organization'] as String, email: m['email'] as String,
    phone: (m['phone'] as String?) ?? '',
    passwordHash: (m['passwordHash'] as String?) ?? '',
  );
}

String _encodeSaved(SavedAccount a) => jsonEncode({
  'login': a.login, 'displayName': a.displayName, 'initials': a.initials,
});

SavedAccount _decodeSaved(String s) {
  final m = jsonDecode(s) as Map<String, dynamic>;
  return SavedAccount(
    login: m['login'] as String,
    displayName: m['displayName'] as String,
    initials: m['initials'] as String,
  );
}

// ─── Repository ───────────────────────────────────────────────

class AppRepository {
  final SharedPreferences _prefs;

  // In-memory collections. Users and saved accounts are seeded from
  // SharedPreferences on construction; GIS data stays ephemeral (mock).
  late List<AppUser> _users;
  late List<SavedAccount> _savedAccounts;
  final List<GisObject> _objects = List.from(_seedObjects);
  final List<AttributeTable> _tables = List.from(_seedTables);
  final List<GisFile> _globalFiles = List.from(_seedGlobalFiles);
  final Map<String, List<GisLayer>> _layersCache = {};
  final Map<String, List<GisFile>> _filesCache = {};

  static const _d  = Duration(milliseconds: 600);
  static const _ds = Duration(milliseconds: 250);

  AppRepository(this._prefs) {
    _users         = _loadUsers();
    _savedAccounts = _loadSavedAccounts();
  }

  // ── Persistence helpers ───────────────────────────────────

  List<AppUser> _loadUsers() {
    final stored = _prefs.getStringList(_kUsers);
    if (stored != null && stored.isNotEmpty) {
      return stored.map(_decodeUser).toList();
    }
    // First launch — seed the default admin and write to disk.
    const seed = AppUser(
      id: 'u1', login: 'admin', firstName: 'Иван', lastName: 'Петров',
      organization: 'АгроГИС', email: 'admin@gis.ru',
      phone: '+7 900 123-45-67', passwordHash: '123456',
    );
    _prefs.setStringList(_kUsers, [_encodeUser(seed)]);
    return [seed];
  }

  List<SavedAccount> _loadSavedAccounts() {
    final stored = _prefs.getStringList(_kSaved) ?? [];
    return stored.map(_decodeSaved).toList();
  }

  void _persistUsers() =>
      _prefs.setStringList(_kUsers, _users.map(_encodeUser).toList());

  void _persistSavedAccounts() =>
      _prefs.setStringList(_kSaved, _savedAccounts.map(_encodeSaved).toList());

  // ── Auth persistence ──────────────────────────────────────

  /// Login of the user who was logged in when the app was last closed.
  /// Returns null if no session was saved.
  String? get restoredLogin => _prefs.getString(_kAuthLogin);

  void persistAuth(String login) => _prefs.setString(_kAuthLogin, login);

  void clearAuth() => _prefs.remove(_kAuthLogin);

  SyncStatus getSyncStatus() {
      final stored = _prefs.getString(_kSyncStatus);
      return SyncStatus.values.firstWhere(
        (s) => s.name == stored,
        orElse: () => SyncStatus.localOnly,
      );
    } 
    
    void persistSyncStatus(SyncStatus status) =>
        _prefs.setString(_kSyncStatus, status.name);

  // ── Auth ──────────────────────────────────────────────────

  Future<AppUser?> login(String login, String password) async {
    await Future.delayed(_ds);
    try {
      return _users.firstWhere((u) => u.login == login && u.passwordHash == password);
    } catch (_) { return null; }
  }

  Future<AppUser> register({required String login, required String password,
      required String firstName, required String lastName,
      required String organization, required String email}) async {
    await Future.delayed(_ds);
    final user = AppUser(
      id: 'u${DateTime.now().millisecondsSinceEpoch}',
      login: login, firstName: firstName, lastName: lastName,
      organization: organization, email: email, passwordHash: password,
    );
    _users.add(user);
    _persistUsers();
    return user;
  }

  Future<AppUser> updateProfile(AppUser updated) async {
    await Future.delayed(_ds);
    final idx = _users.indexWhere((u) => u.id == updated.id);
    if (idx != -1) {
      _users[idx] = updated;
      _persistUsers();
    }
    return updated;
  }

  Future<String?> changePassword(String login, String currentPassword, String newPassword) async {
    await Future.delayed(_ds);
    final idx = _users.indexWhere((u) => u.login == login);
    if (idx == -1) return 'Пользователь не найден';
    if (_users[idx].passwordHash != currentPassword) return 'Неверный текущий пароль';
    final u = _users[idx];
    _users[idx] = AppUser(
      id: u.id, login: u.login, firstName: u.firstName, lastName: u.lastName,
      organization: u.organization, email: u.email, phone: u.phone,
      passwordHash: newPassword,
    );
    _persistUsers();
    return null;
  }

  List<SavedAccount> getSavedAccounts() => List.unmodifiable(_savedAccounts);

  void saveAccount(AppUser user) {
    _savedAccounts.removeWhere((a) => a.login == user.login);
    _savedAccounts.insert(0, SavedAccount(
      login: user.login, displayName: user.fullName, initials: user.initials,
    ));
    _persistSavedAccounts();
  }

  void removeSavedAccount(String login) {
    _savedAccounts.removeWhere((a) => a.login == login);
    _persistSavedAccounts();
  }

  AppUser? getUserByLogin(String login) {
    try { return _users.firstWhere((u) => u.login == login); }
    catch (_) { return null; }
  }

  /// Returns true if `login` is already used by another user.
  /// Pass `excludeId` to ignore the user currently being updated.
  bool isLoginTaken(String login, {String? excludeId}) =>
      _users.any((u) => u.login == login && u.id != excludeId);

  /// Updates the saved account entry in place when a user renames their login.
  void updateSavedAccount(String oldLogin, AppUser updated) {
    final idx = _savedAccounts.indexWhere((a) => a.login == oldLogin);
    if (idx == -1) return;
    _savedAccounts[idx] = SavedAccount(
      login: updated.login,
      displayName: updated.fullName,
      initials: updated.initials,
    );
    _persistSavedAccounts();
  }

  // ── GIS Objects ───────────────────────────────────────────

  Future<List<GisCategory>> fetchCategories() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.unmodifiable(_categories);
  }

  Future<List<GisObject>> fetchObjects() async {
    await Future.delayed(_d);
    return List.unmodifiable(_objects);
  }

  Future<List<GisLayer>> fetchLayers(String objectId) async {
    await Future.delayed(_ds);
    if (_layersCache.containsKey(objectId)) return _layersCache[objectId]!;
    final obj = _objects.where((o) => o.id == objectId).firstOrNull;
    final layers = List<GisLayer>.from(obj?.layers ?? []);
    _layersCache[objectId] = layers;
    return layers;
  }

  Future<void> updateLayerVisibility(String objectId, String layerId, bool visible) async {
    final layers = _layersCache[objectId];
    if (layers == null) return;
    final idx = layers.indexWhere((l) => l.id == layerId);
    if (idx != -1) layers[idx] = layers[idx].copyWith(isVisible: visible);
  }

  Future<void> deleteLayer(String objectId, String layerId) async {
    _layersCache[objectId]?.removeWhere((l) => l.id == layerId);
  }

  Future<void> addObject(GisObject obj) async {
    await Future.delayed(_ds);
    _objects.insert(0, obj);
  }

  Future<void> addLayer(String objectId, GisLayer layer) async {
    await Future.delayed(_ds);
    _layersCache.putIfAbsent(objectId, () {
      final obj = _objects.where((o) => o.id == objectId).firstOrNull;
      return List<GisLayer>.from(obj?.layers ?? []);
    });
    _layersCache[objectId]!.add(layer);
  }

  // ── Files ─────────────────────────────────────────────────

  Future<List<GisFile>> fetchFiles(String objectId) async {
    await Future.delayed(_ds);
    if (_filesCache.containsKey(objectId)) return _filesCache[objectId]!;
    final fileList = _files(objectId);
    _filesCache[objectId] = fileList;
    return fileList;
  }

  // ── Global file storage ───────────────────────────────────

  /// Adds a file to global storage and returns it wrapped with object context.
  FileWithObject addGlobalFile(GisFile f) {
    _globalFiles.add(f);
    return _wrapGlobal(f);
  }

  List<GisFile> getGlobalFiles() => List.unmodifiable(_globalFiles);

  /// Adds a file directly into an object's cache (not global storage).
  /// Used when the user picks an object during file creation.
  FileWithObject addFileToObject(String objectId, GisFile f) {
    _filesCache.putIfAbsent(objectId, () => _files(objectId));
    if (!_filesCache[objectId]!.any((e) => e.id == f.id)) {
      _filesCache[objectId]!.add(f);
    }
    final obj = _objects.firstWhere((o) => o.id == objectId,
        orElse: () => _objects.first);
    return FileWithObject(
      file: f,
      objectId: objectId,
      objectName: obj.name,
      objectIcon: obj.icon,
      objectColor: obj.category.color,
    );
  }

  /// Attaches a (global) file to a specific object's file cache.
  void attachFileToObject(String objectId, GisFile f) {
    _filesCache.putIfAbsent(objectId, () => _files(objectId));
    if (_filesCache[objectId]!.any((e) => e.id == f.id)) return;
    _filesCache[objectId]!.add(f);
  }

  FileWithObject _wrapGlobal(GisFile f) => FileWithObject(
    file: f,
    objectId: '',
    objectName: 'Хранилище',
    objectIcon: Icons.storage_rounded,
    objectColor: AppColors.layerPolyline,
  );

  Future<List<FileWithObject>> fetchAllFiles() async {
    await Future.delayed(_d);
    final result = <FileWithObject>[];
    // Global (unbound) files first.
    for (final f in _globalFiles) result.add(_wrapGlobal(f));
    // Per-object files.
    for (final obj in _objects) {
      if (!_filesCache.containsKey(obj.id)) {
        _filesCache[obj.id] = _files(obj.id);
      }
      for (final f in _filesCache[obj.id]!) {
        result.add(FileWithObject(
          file: f,
          objectId: obj.id,
          objectName: obj.name,
          objectIcon: obj.icon,
          objectColor: obj.category.color,
        ));
      }
    }
    return result;
  }

  void deleteFiles(Set<String> ids) {
    _globalFiles.removeWhere((f) => ids.contains(f.id));
    for (final list in _filesCache.values) {
      list.removeWhere((f) => ids.contains(f.id));
    }
  }

  // ── Tables ────────────────────────────────────────────────

  Future<List<AttributeTable>> fetchTables() async {
    await Future.delayed(_d);
    return List.unmodifiable(_tables);
  }

  Future<AttributeTable> createTable(AttributeTable t) async {
    await Future.delayed(_ds);
    _tables.insert(0, t);
    return t;
  }

  Future<AttributeTable> updateTable(AttributeTable t) async {
    await Future.delayed(_ds);
    final idx = _tables.indexWhere((x) => x.id == t.id);
    final updated = t.copyWith(updatedAt: DateTime.now());
    if (idx != -1) _tables[idx] = updated;
    return updated;
  }

  Future<void> deleteTable(String id) async {
    await Future.delayed(_ds);
    _tables.removeWhere((t) => t.id == id);
  }
}
