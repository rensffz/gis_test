// lib/models/app_models.dart
// Единый файл моделей приложения.
// Все модели чистые Dart-классы, не зависят от БД.

import 'package:flutter/material.dart';
import '../core/app_theme.dart';

// ─── USER ─────────────────────────────────────────────────────
class AppUser {
  final String id;
  final String login;
  final String firstName;
  final String lastName;
  final String organization;
  final String email;
  final String phone;
  final String passwordHash; // в реальном приложении — хэш

  const AppUser({
    required this.id,
    required this.login,
    required this.firstName,
    required this.lastName,
    required this.organization,
    required this.email,
    this.phone = '',
    this.passwordHash = '',
  });

  String get fullName {
    final parts = [firstName, lastName].where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(' ') : login;
  }

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return (f + l).isNotEmpty ? f + l : login[0].toUpperCase();
  }

  AppUser copyWith({
    String? login,
    String? firstName, String? lastName, String? organization,
    String? email, String? phone,
  }) => AppUser(
    id: id,
    login: login ?? this.login,
    passwordHash: passwordHash,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    organization: organization ?? this.organization,
    email: email ?? this.email,
    phone: phone ?? this.phone,
  );
}

// ─── SAVED ACCOUNT ────────────────────────────────────────────
class SavedAccount {
  final String login;
  final String displayName;
  final String initials;

  const SavedAccount({
    required this.login,
    required this.displayName,
    required this.initials,
  });
}

// ─── CATEGORY ─────────────────────────────────────────────────
class GisCategory {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  const GisCategory({required this.id, required this.name, required this.color, required this.icon});
}

// ─── LAYER TYPE ───────────────────────────────────────────────
enum LayerType { area, points, orthophoto }

extension LayerTypeX on LayerType {
  String get label => const {
    LayerType.area:       'AREA',
    LayerType.points:     'POINTS',
    LayerType.orthophoto: 'ORTHOPHOTO',
  }[this]!;

  IconData get icon => const {
    LayerType.area:       Icons.pentagon_outlined,
    LayerType.points:     Icons.radio_button_checked_rounded,
    LayerType.orthophoto: Icons.grid_on_rounded,
  }[this]!;

  Color get color => const {
    LayerType.area:       AppColors.layerPolygon,
    LayerType.points:     AppColors.layerPoint,
    LayerType.orthophoto: AppColors.layerRaster,
  }[this]!;

  bool get supportsTable => this == LayerType.points;
  bool get requiresFile  => this == LayerType.orthophoto;
}

// ─── LAYER ────────────────────────────────────────────────────
class GisLayer {
  final String id;
  final String name;
  final LayerType type;
  final Color color;
  final bool isVisible;
  final int objectsCount;
  final String? tableId;
  final String? fileId;
  const GisLayer({required this.id, required this.name, required this.type,
      required this.color, required this.isVisible, required this.objectsCount,
      this.tableId, this.fileId});
  GisLayer copyWith({bool? isVisible}) => GisLayer(
    id: id, name: name, type: type, color: color, objectsCount: objectsCount,
    isVisible: isVisible ?? this.isVisible, tableId: tableId, fileId: fileId,
  );
}

// ─── GIS OBJECT ───────────────────────────────────────────────
class GisObject {
  final String id;
  final String name;
  final String description;
  final GisCategory category;
  final List<GisLayer> layers;
  final DateTime updatedAt;
  final IconData icon;
  const GisObject({required this.id, required this.name, required this.description,
      required this.category, required this.layers, required this.updatedAt, required this.icon});
  int get layerCount => layers.length;
  int get totalObjects => layers.fold(0, (s, l) => s + l.objectsCount);
}

// ─── FILE TYPE ────────────────────────────────────────────────
enum FileType { image, video, geotiff, document, pointcloud, other }

// Types users may select when creating a new file.
// Existing files with other types remain valid (mock seed data).
const kAllowedFileTypes = [FileType.geotiff, FileType.other];

extension FileTypeX on FileType {
  String get label => const {
    FileType.image: 'Image', FileType.video: 'Video', FileType.geotiff: '.tif',
    FileType.document: 'Document', FileType.pointcloud: 'Point Cloud', FileType.other: 'FILE',
  }[this]!;
  IconData get icon => const {
    FileType.image: Icons.image_outlined, FileType.video: Icons.videocam_outlined,
    FileType.geotiff: Icons.map_outlined, FileType.document: Icons.description_outlined,
    FileType.pointcloud: Icons.scatter_plot_outlined, FileType.other: Icons.insert_drive_file_outlined,
  }[this]!;
  Color get color => const {
    FileType.image: AppColors.layerPoint, FileType.video: AppColors.layerHeatmap,
    FileType.geotiff: AppColors.layerPolygon, FileType.document: AppColors.layerPolyline,
    FileType.pointcloud: AppColors.layerRaster, FileType.other: AppColors.textSecondary,
  }[this]!;
}

class GisFile {
  final String id;
  final String name;
  final String description;
  final FileType type;
  final int sizeBytes;
  final DateTime createdAt;
  const GisFile({required this.id, required this.name, required this.type,
      required this.sizeBytes, required this.createdAt, this.description = ''});
  String get sizeLabel {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ─── DATA TYPE ───────────────────────────────────────────────
enum DataType { integer, double_, string }

extension DataTypeX on DataType {
  String get label => const {
    DataType.integer: 'INTEGER',
    DataType.double_: 'DOUBLE',
    DataType.string: 'STRING',
  }[this]!;
  IconData get icon => const {
    DataType.integer: Icons.tag_rounded,
    DataType.double_: Icons.calculate_outlined,
    DataType.string: Icons.text_fields_rounded,
  }[this]!;
}

// ─── ATTRIBUTE TABLE ──────────────────────────────────────────
class AttributeProperty {
  final String id;
  final String name;
  final String description;
  final String measurementUnit;
  final DataType dataType;
  const AttributeProperty({required this.id, required this.name,
      required this.description, required this.measurementUnit,
      this.dataType = DataType.string});
  AttributeProperty copyWith({String? name, String? description,
      String? measurementUnit, DataType? dataType}) =>
      AttributeProperty(id: id, name: name ?? this.name,
          description: description ?? this.description,
          measurementUnit: measurementUnit ?? this.measurementUnit,
          dataType: dataType ?? this.dataType);
}

class AttributeTable {
  final String id;
  final String name;
  final String description;
  final List<AttributeProperty> properties;
  final DateTime updatedAt;
  const AttributeTable({required this.id, required this.name, required this.description,
      required this.properties, required this.updatedAt});
  int get propertyCount => properties.length;
  AttributeTable copyWith({String? name, String? description,
      List<AttributeProperty>? properties, DateTime? updatedAt}) =>
      AttributeTable(id: id, name: name ?? this.name,
          description: description ?? this.description,
          properties: properties ?? this.properties,
          updatedAt: updatedAt ?? this.updatedAt);
}

// ─── FILE WITH OBJECT CONTEXT ─────────────────────────────────
class FileWithObject {
  final GisFile file;
  final String objectId;
  final String objectName;
  final IconData objectIcon;
  final Color objectColor;
  const FileWithObject({
    required this.file,
    required this.objectId,
    required this.objectName,
    required this.objectIcon,
    required this.objectColor,
  });
}

// ─── MAP DEMO POINT ───────────────────────────────────────────
class MapDemoPoint {
  final double x, y;
  final String label;
  final Color color;
  // Attribute values keyed by AttributeProperty.id, matching the linked table.
  final Map<String, String> attributes;
  const MapDemoPoint({required this.x, required this.y, required this.label,
      required this.color, this.attributes = const {}});
  MapDemoPoint copyWith({String? label, Map<String, String>? attributes}) => MapDemoPoint(
    x: x, y: y, label: label ?? this.label, color: color,
    attributes: attributes ?? this.attributes);
}

// ─── SYNC STATUS ──────────────────────────────────────────────
  enum SyncStatus { localOnly, pending, synced, conflict }
