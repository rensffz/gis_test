// lib/providers/app_providers.dart
// Единый файл всех Riverpod-провайдеров приложения.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import '../repositories/app_repository.dart';

// ─── SharedPreferences singleton (overridden in main before runApp) ──────────
final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('prefsProvider must be overridden in main'),
);

// ─── Repository singleton ─────────────────────────────────────
final repoProvider = Provider<AppRepository>(
  (ref) => AppRepository(ref.read(prefsProvider)),
);

// ─── Theme ────────────────────────────────────────────────────
final isDarkProvider = StateProvider<bool>((ref) => true);

// ═══════════════════════════════════════════════════════════════
// AUTH STATE
// ═══════════════════════════════════════════════════════════════
class AuthNotifier extends StateNotifier<AppUser?> {
  final AppRepository _repo;
  AuthNotifier(this._repo) : super(null) {
    _restore();
  }

  // Restores the previously logged-in user from disk on app startup.
  void _restore() {
    final login = _repo.restoredLogin;
    if (login == null) return;
    final user = _repo.getUserByLogin(login);
    if (user != null) state = user;
  }

  bool get isLoggedIn => state != null;

  Future<String?> login(String login, String password) async {
    final user = await _repo.login(login, password);
    if (user == null) return 'Неверный логин или пароль';
    _repo.saveAccount(user);
    _repo.persistAuth(user.login);
    state = user;
    return null;
  }

  Future<String?> register({required String login, required String password,
      required String firstName, required String lastName,
      required String organization, required String email}) async {
    if (_repo.isLoginTaken(login)) return 'Логин уже занят';
    final user = await _repo.register(
      login: login, password: password, firstName: firstName,
      lastName: lastName, organization: organization, email: email,
    );
    _repo.saveAccount(user);
    _repo.persistAuth(user.login);
    state = user;
    return null;
  }

  void logout() {
    if (state != null) _repo.saveAccount(state!);
    _repo.clearAuth();
    state = null;
  }

  Future<String?> updateProfile(AppUser updated) async {
    final oldLogin = state?.login;
    final loginChanged = oldLogin != null && oldLogin != updated.login;
    if (loginChanged && _repo.isLoginTaken(updated.login, excludeId: updated.id)) {
      return 'Логин уже занят';
    }
    final saved = await _repo.updateProfile(updated);
    // Keep the saved-accounts entry current (name, initials, login).
    if (oldLogin != null) _repo.updateSavedAccount(oldLogin, saved);
    // Auth session key is the login — update if it changed.
    if (loginChanged) _repo.persistAuth(saved.login);
    state = saved;
    return null;
  }

  List<SavedAccount> get savedAccounts => _repo.getSavedAccounts();

  void quickLogin(String login) {
    final user = _repo.getUserByLogin(login);
    if (user != null) {
      _repo.persistAuth(user.login);
      state = user;
    }
  }

  void removeSavedAccount(String login) {
    _repo.removeSavedAccount(login);
    // Widget calls setState() after this — savedAccounts is re-read from repo.
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    if (state == null) return 'Не авторизован';
    return _repo.changePassword(state!.login, currentPassword, newPassword);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>(
  (ref) => AuthNotifier(ref.read(repoProvider)),
);

// ═══════════════════════════════════════════════════════════════
// CATEGORIES
// ═══════════════════════════════════════════════════════════════
final categoriesProvider = FutureProvider<List<GisCategory>>((ref) {
  return ref.read(repoProvider).fetchCategories();
});

// ═══════════════════════════════════════════════════════════════
// OBJECTS STATE
// ═══════════════════════════════════════════════════════════════
final objectsProvider = FutureProvider<List<GisObject>>((ref) {
  return ref.read(repoProvider).fetchObjects();
});

final objectSearchProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final filteredObjectsProvider = Provider<AsyncValue<List<GisObject>>>((ref) {
  final raw = ref.watch(objectsProvider);
  final query = ref.watch(objectSearchProvider).toLowerCase().trim();
  final cat = ref.watch(selectedCategoryProvider);
  return raw.whenData((list) {
    var r = list;
    if (cat != null) r = r.where((o) => o.category.id == cat).toList();
    if (query.isNotEmpty) r = r.where((o) =>
      o.name.toLowerCase().contains(query) ||
      o.description.toLowerCase().contains(query)).toList();
    return r;
  });
});

// ═══════════════════════════════════════════════════════════════
// LAYERS STATE (per-object)
// ═══════════════════════════════════════════════════════════════
class LayersNotifier extends StateNotifier<AsyncValue<List<GisLayer>>> {
  final AppRepository _repo;
  final String objectId;
  LayersNotifier(this._repo, this.objectId) : super(const AsyncValue.loading()) { _load(); }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try { state = AsyncValue.data(await _repo.fetchLayers(objectId)); }
    catch (e, st) { state = AsyncValue.error(e, st); }
  }

  Future<void> toggleVisibility(String layerId) async {
    final cur = state.valueOrNull;
    if (cur == null) return;
    final newList = cur.map((l) => l.id == layerId ? l.copyWith(isVisible: !l.isVisible) : l).toList();
    state = AsyncValue.data(newList);
    await _repo.updateLayerVisibility(objectId, layerId, newList.firstWhere((l) => l.id == layerId).isVisible);
  }

  Future<void> deleteLayer(String layerId) async {
    final cur = state.valueOrNull;
    if (cur == null) return;
    state = AsyncValue.data(cur.where((l) => l.id != layerId).toList());
    await _repo.deleteLayer(objectId, layerId);
  }

  Future<void> addLayer(GisLayer layer) async {
    await _repo.addLayer(objectId, layer);
    final cur = state.valueOrNull ?? [];
    state = AsyncValue.data([...cur, layer]);
  }
}

final layersProvider = StateNotifierProvider.family<LayersNotifier, AsyncValue<List<GisLayer>>, String>(
  (ref, objectId) => LayersNotifier(ref.read(repoProvider), objectId),
);

// ═══════════════════════════════════════════════════════════════
// FILES STATE (per-object — used by map screen file sheet)
// ═══════════════════════════════════════════════════════════════
final filesProvider = FutureProvider.family<List<GisFile>, String>((ref, objectId) {
  return ref.read(repoProvider).fetchFiles(objectId);
});

// ═══════════════════════════════════════════════════════════════
// ALL FILES STATE (flat list across all objects)
// ═══════════════════════════════════════════════════════════════
class AllFilesNotifier extends StateNotifier<AsyncValue<List<FileWithObject>>> {
  final AppRepository _repo;
  AllFilesNotifier(this._repo) : super(const AsyncValue.loading()) { _load(); }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try { state = AsyncValue.data(await _repo.fetchAllFiles()); }
    catch (e, st) { state = AsyncValue.error(e, st); }
  }

  void addGlobal(GisFile f) {
    final fw = _repo.addGlobalFile(f);
    final cur = state.valueOrNull;
    if (cur == null) return;
    state = AsyncValue.data([fw, ...cur]);
  }

  void addToObject(String objectId, GisFile f) {
    final fw = _repo.addFileToObject(objectId, f);
    final cur = state.valueOrNull;
    if (cur == null) return;
    state = AsyncValue.data([fw, ...cur]);
  }

  void delete(Set<String> ids) {
    _repo.deleteFiles(ids);
    final cur = state.valueOrNull;
    if (cur == null) return;
    state = AsyncValue.data(cur.where((f) => !ids.contains(f.file.id)).toList());
  }
}

final allFilesProvider =
    StateNotifierProvider<AllFilesNotifier, AsyncValue<List<FileWithObject>>>(
  (ref) => AllFilesNotifier(ref.read(repoProvider)),
);

final selectedFileIdsProvider = StateProvider<Set<String>>((ref) => {});

// Derived list of files that live in global storage (objectId == '').
// Used by the object-level file picker ("Select from storage").
final globalFilesProvider = Provider<List<GisFile>>((ref) {
  final all = ref.watch(allFilesProvider).valueOrNull ?? [];
  return all.where((fw) => fw.objectId.isEmpty).map((fw) => fw.file).toList();
});

final fileSearchProvider = StateProvider<String>((ref) => '');

final filteredFilesProvider = Provider<AsyncValue<List<FileWithObject>>>((ref) {
  final raw = ref.watch(allFilesProvider);
  final q   = ref.watch(fileSearchProvider).toLowerCase().trim();
  return raw.whenData((list) => q.isEmpty ? list : list.where((fw) =>
    fw.file.name.toLowerCase().contains(q) ||
    fw.objectName.toLowerCase().contains(q)).toList());
});

// ═══════════════════════════════════════════════════════════════
// TABLES STATE
// ═══════════════════════════════════════════════════════════════
final tableSearchProvider = StateProvider<String>((ref) => '');

class TablesNotifier extends StateNotifier<AsyncValue<List<AttributeTable>>> {
  final AppRepository _repo;
  TablesNotifier(this._repo) : super(const AsyncValue.loading()) { _load(); }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try { state = AsyncValue.data(await _repo.fetchTables()); }
    catch (e, st) { state = AsyncValue.error(e, st); }
  }

  Future<void> reload() => _load();

  Future<void> create(AttributeTable t) async {
    final created = await _repo.createTable(t);
    state = AsyncValue.data([created, ...?state.valueOrNull]);
  }

  Future<void> update(AttributeTable t) async {
    final saved = await _repo.updateTable(t);
    state = AsyncValue.data(state.valueOrNull?.map((x) => x.id == saved.id ? saved : x).toList() ?? []);
  }

  Future<void> delete(String id) async {
    final prev = state.valueOrNull ?? [];
    state = AsyncValue.data(prev.where((t) => t.id != id).toList());
    try { await _repo.deleteTable(id); }
    catch (_) { state = AsyncValue.data(prev); rethrow; }
  }
}

final tablesProvider = StateNotifierProvider<TablesNotifier, AsyncValue<List<AttributeTable>>>(
  (ref) => TablesNotifier(ref.read(repoProvider)),
);

final filteredTablesProvider = Provider<AsyncValue<List<AttributeTable>>>((ref) {
  final raw = ref.watch(tablesProvider);
  final q = ref.watch(tableSearchProvider).toLowerCase().trim();
  return raw.whenData((list) => q.isEmpty ? list :
    list.where((t) => t.name.toLowerCase().contains(q) || t.description.toLowerCase().contains(q)).toList());
});
