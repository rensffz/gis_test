// lib/routing/app_router.dart
//
// Почему GoRouter, а не AutoRoute:
//   - Нет кодогенерации → нет build_runner → быстрее сборка
//   - Встроенный redirect с доступом к auth state
//   - ShellRoute для единого AppShell + Drawer
//   - Официальный пакет Flutter team, стабильный API
//   - Поддержка deep links из коробки

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/app_models.dart';
import '../providers/app_providers.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_step1_screen.dart';
import '../features/auth/screens/register_step2_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/gis/screens/objects_screen.dart';
import '../features/gis/screens/object_map_screen.dart';
import '../features/tables/screens/tables_screen.dart';
import '../features/tables/screens/table_editor_screen.dart';
import '../features/tables/screens/table_details_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/files/screens/files_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../shared/widgets/app_shell.dart';

// ─── Маршруты ─────────────────────────────────────────────────
class AppRoutes {
  static const login        = '/login';
  static const register1    = '/register/step1';
  static const register2    = '/register/step2';
  static const dashboard    = '/dashboard';
  static const objects      = '/objects';
  static const tables       = '/tables';
  static const tableNew     = '/tables/new';
  static const tableEdit    = '/tables/:tableId/edit';
  static const tableDetails = '/tables/:tableId';
  static const profile      = '/profile';
  static const files        = '/files';
  static const settings     = '/settings';
}

// ─── Auth refresh notifier ────────────────────────────────────
// Соединяет Riverpod auth state → GoRouter refresh.
// Хранит ссылку на notifier ОДИН раз, не пересоздаётся.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// ─── Router provider ──────────────────────────────────────────
// Provider<GoRouter> создаётся один раз благодаря autoDispose: false (default).
// ref.read используется для redirect, чтобы не пересоздавать роутер при смене auth.
final routerProvider = Provider<GoRouter>((ref) {
  // Создаём refresh notifier один раз
  final refreshNotifier = _AuthRefreshNotifier(
    ref.read(authProvider.notifier).stream,
  );
  // Удаляем при dispose провайдера
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.login,
    refreshListenable: refreshNotifier,

    // ── Auth guard ───────────────────────────────────────────
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider) != null;
      final loc = state.matchedLocation;
      final onAuthPage = loc == AppRoutes.login ||
          loc == AppRoutes.register1 ||
          loc == AppRoutes.register2;

      // Не авторизован и пытается попасть на защищённый маршрут
      if (!loggedIn && !onAuthPage) return AppRoutes.login;
      // Авторизован и на странице логина/регистрации
      if (loggedIn && onAuthPage) return AppRoutes.dashboard;
      return null;
    },

    routes: [
      // ── Auth flow (без AppShell — нет Drawer) ─────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register1,
        builder: (_, __) => const RegisterStep1Screen(),
      ),
      GoRoute(
        path: AppRoutes.register2,
        builder: (_, state) => RegisterStep2Screen(
          password: state.extra as String? ?? '',
        ),
      ),

      // ── Protected shell (с AppShell — есть Drawer) ────────
      // ShellRoute оборачивает все дочерние маршруты в AppShell.
      // child — текущий активный экран дочернего маршрута.
      ShellRoute(
        builder: (context, state, child) => AppShell(
          child: child,
          location: state.matchedLocation,
        ),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (_, __) => const DashboardScreen(),
          ),

          // GIS: список объектов + карта как subroute
          GoRoute(
            path: AppRoutes.objects,
            builder: (_, __) => const ObjectsScreen(),
            routes: [
              GoRoute(
                path: ':objectId/map',
                // Выходит из ShellRoute — карта занимает весь экран без Drawer
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, state) => ObjectMapScreen(
                  objectId: state.pathParameters['objectId']!,
                  initialObject: state.extra as GisObject?,
                ),
              ),
            ],
          ),

          // Таблицы
          GoRoute(
            path: AppRoutes.tables,
            builder: (_, __) => const TablesScreen(),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, __) => const TableEditorScreen(),
              ),
              GoRoute(
                path: ':tableId/edit',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, state) => TableEditorScreen(
                  tableId: state.pathParameters['tableId'],
                ),
              ),
              GoRoute(
                path: ':tableId',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (_, state) => TableDetailsScreen(
                  tableId: state.pathParameters['tableId']!,
                  fromObjectId: state.extra is String ? state.extra as String : null,
                ),
              ),
            ],
          ),

          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.files,
            builder: (_, __) => const FilesScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

// Ключ корневого навигатора — нужен для маршрутов,
// которые должны перекрывать ShellRoute (карта, редактор таблиц).
final _rootNavigatorKey = GlobalKey<NavigatorState>();
