// lib/shared/keys.dart
// Глобальные ключи приложения.
// Отдельный файл — избегает циклических зависимостей между
// app_shell.dart и common_widgets.dart.

import 'package:flutter/material.dart';

/// Ключ Scaffold в AppShell.
/// Используется для открытия Drawer из любого дочернего экрана.
final shellScaffoldKey = GlobalKey<ScaffoldState>();
