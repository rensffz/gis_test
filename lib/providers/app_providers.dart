 // lib/providers/app_providers.dart
  // Единый файл всех Riverpod-провайдеров приложения.
  
  import 'dart:async' show unawaited;
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import '../models/app_models.dart';
  import '../repositories/app_repository.dart';
  import '../services/user_api_service.dart';
  
  // ─── SharedPreferences singleton (overridden in main before runApp) ──────────
  final prefsProvider = Provider<SharedPreferences>(
    (_) => throw UnimplementedError('prefsProvider must be overridden in main'),
  );

  // ─── Repository singleton ─────────────────────────────────────
  final repoProvider = Provider<AppRepository>(
    (ref) => AppRepository(ref.read(prefsProvider)),
  );

  // ─── User API Service singleton ───────────────────────────────
  final userApiServiceProvider = Provider<UserApiService>(
    (_) => UserApiService(),
  );

  // ─── Theme ────────────────────────────────────────────────────
  final isDarkProvider = StateProvider<bool>((ref) => true);

  // ─── Sync Status ──────────────────────────────────────────────
  // Initialised from persisted value so it survives cold restarts.
  final userSyncStatusProvider = StateProvider<SyncStatus>(
    (ref) => ref.read(repoProvider).getSyncStatus(),
  );

  // ═══════════════════════════════════════════════════════════════
  // AUTH STATE
  // ═══════════════════════════════════════════════════════════════
  class AuthNotifier extends StateNotifier<AppUser?> {
    final AppRepository _repo;
    final UserApiService _api;
    final Ref _ref;

    AuthNotifier(this._repo, this._api, this._ref) : super(null) {
      _restore();
    }

    // ── Helpers ───────────────────────────────────────────────

    void _setSyncStatus(SyncStatus status) {
      if (!mounted) return;
      _repo.persistSyncStatus(status);
      try {
        _ref.read(userSyncStatusProvider.notifier).state = status;
      } catch (_) {}
    }

    // ── Session restore ───────────────────────────────────────

    void _restore() {
      final login = _repo.restoredLogin;
      if (login == null) return;
      final user = _repo.getUserByLogin(login);
      if (user != null) {
        state = user;
        unawaited(_syncFromServer());
      }
    }

    bool get isLoggedIn => state != null;

    // ── Auth ──────────────────────────────────────────────────

    Future<String?> login(String login, String password) async {
      final user = await _repo.login(login, password);
      if (user == null) return 'Неверный логин или пароль';
      _repo.saveAccount(user);
      _repo.persistAuth(user.login);
      state = user;
      unawaited(_syncFromServer());
      return null;
    }

    Future<String?> register({
      required String login,
      required String password,
      required String firstName,
      required String lastName,
      required String organization,
      required String email,
    }) async {
      if (_repo.isLoginTaken(login)) return 'Логин уже занят';
      final user = await _repo.register(
        login: login, password: password, firstName: firstName,
        lastName: lastName, organization: organization, email: email,
      );
      _repo.saveAccount(user);
      _repo.persistAuth(user.login);
      state = user;
      unawaited(_createOnServer(user, password));
      return null;
    }

    void logout() {
      if (state != null) _repo.saveAccount(state!);
      _repo.clearAuth();
      _setSyncStatus(SyncStatus.localOnly);
      state = null;
    }

    Future<String?> updateProfile(AppUser updated) async {
      final oldLogin = state?.login;
      final loginChanged = oldLogin != null && oldLogin != updated.login;
      if (loginChanged && _repo.isLoginTaken(updated.login, excludeId: updated.id)) {
        return 'Логин уже занят';
      }
      final saved = await _repo.updateProfile(updated);
      if (oldLogin != null) _repo.updateSavedAccount(oldLogin, saved);
      if (loginChanged) _repo.persistAuth(saved.login);
      state = saved;
      unawaited(_pushToServer(saved));
      return null;
    }

    List<SavedAccount> get savedAccounts => _repo.getSavedAccounts();
  
    void quickLogin(String login) {
      final user = _repo.getUserByLogin(login);
      if (user != null) {
        _repo.persistAuth(user.login);
        state = user;
        unawaited(_syncFromServer());
      }
    }

    void removeSavedAccount(String login) {
      _repo.removeSavedAccount(login);
    }

    Future<String?> changePassword(String currentPassword, String newPassword) async {
      if (state == null) return 'Не авторизован';
      final login = state!.login;
      final error = await _repo.changePassword(login, currentPassword, newPassword);
      if (error != null) return error;
      // Re-read from repo to get updated passwordHash in state.
      final updated = _repo.getUserByLogin(login);
      if (updated != null) state = updated;
      unawaited(_pushPasswordToServer(login, currentPassword, newPassword));
      return null;
    }

    // ══════════════════════════════════════════════════════════
    // SYNC
    // ══════════════════════════════════════════════════════════

    // GET /user → merge into local state.
    // Called on: app restore, login, quickLogin.
    Future<void> _syncFromServer() async {
      if (state == null || !mounted) return;
      _setSyncStatus(SyncStatus.pending);
      try {
        final dto = await _api.getUser(id: state!.id);
        if (!mounted) return;
        if (dto == null) {
          _setSyncStatus(SyncStatus.localOnly);
          return;
        }
        if (state == null || !mounted) return;
        final merged = dto.toAppUser(passwordHash: state!.passwordHash);
        final currentLogin = state!.login;
        await _repo.updateProfile(merged);
        if (!mounted) return;
        _repo.updateSavedAccount(currentLogin, merged);
        if (merged.login != currentLogin) _repo.persistAuth(merged.login);
        state = merged;
        _setSyncStatus(SyncStatus.synced);
      } on ApiException catch (e) {
        if (e.statusCode == 409) {
          _setSyncStatus(SyncStatus.conflict);
          return;
        }
        _setSyncStatus(SyncStatus.localOnly);
      } catch (_) {
        _setSyncStatus(SyncStatus.localOnly);
      }
    }

    Future<void> _createOnServer(AppUser user, String password) async {
      if (!mounted) return;
      _setSyncStatus(SyncStatus.pending);
      try {
        final dto = UserDto.fromAppUser(user);
        await _api.createUser(dto, password);
        _setSyncStatus(SyncStatus.synced);
      } on ApiException {
        _setSyncStatus(SyncStatus.localOnly);
      } catch (_) {
        _setSyncStatus(SyncStatus.localOnly);
      }
    }

    Future<void> _pushToServer(AppUser user) async {
      if (!mounted) return;
      _setSyncStatus(SyncStatus.pending);
      try {
        final dto = UserDto.fromAppUser(user);
        final result = await _api.updateUser(dto);
        if (!mounted) return;
        if (result != null && state != null) {
          final serverUser = result.toAppUser(passwordHash: state!.passwordHash);
          await _repo.updateProfile(serverUser);
          if (!mounted) return;
          state = serverUser;
        }
        _setSyncStatus(SyncStatus.synced);
      } on ApiException catch (e) {
        if (e.statusCode == 409) {
          _setSyncStatus(SyncStatus.conflict);
          return;
        }
        _setSyncStatus(SyncStatus.localOnly);
      } catch (_) {
        _setSyncStatus(SyncStatus.localOnly);
      }
    }

    Future<void> _pushPasswordToServer(
      String login,
      String currentPassword,
      String newPassword,
    ) async {
      if (!mounted) return;
      _setSyncStatus(SyncStatus.pending);
      try {
        await _api.updatePassword(
          login: login,
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
        _setSyncStatus(SyncStatus.synced);
      } on ApiException {
        _setSyncStatus(SyncStatus.localOnly);
      } catch (_) {
        _setSyncStatus(SyncStatus.localOnly);
      }
    }
  }

  final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>(
    (ref) => AuthNotifier(
      ref.read(repoProvider),
      ref.read(userApiServiceProvider),
      ref,
    ),
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
      await _repo.updateLayerVisibility(objectId, layerId, newList.firstWhere((l) => l.id ==
  layerId).isVisible);
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

  final layersProvider = StateNotifierProvider.family<LayersNotifier, AsyncValue<List<GisLayer>>,
  String>(
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
      state = AsyncValue.data(state.valueOrNull?.map((x) => x.id == saved.id ? saved : x).toList() ??
  []);
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
      list.where((t) => t.name.toLowerCase().contains(q) ||
  t.description.toLowerCase().contains(q)).toList());
  });
