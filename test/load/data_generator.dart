// test/load/data_generator.dart
// Генераторы тестовых данных для нагрузочных тестов.
// Создают N объектов с уникальными ID.

import 'package:flutter/material.dart';
import 'package:gis_app/models/app_models.dart';

final _testCategory = const GisCategory(
  id: 'cat_load', name: 'Load Test Category',
  color: Color(0xFF00D4AA), icon: Icons.landscape_rounded,
);

/// Генерирует [count] слоёв для нагрузочного теста.
List<GisLayer> generateLayers(int count, {String prefix = 'load_obj'}) {
  return List.generate(count, (i) => GisLayer(
    id: '${prefix}_l$i',
    name: 'Layer $i',
    type: i.isEven ? LayerType.area : LayerType.points,
    color: const Color(0xFF00D4AA),
    isVisible: i % 3 != 0, // каждый 3-й скрытый
    objectsCount: i * 10,
    tableId: i.isOdd ? 'tbl_load_$i' : null,
  ));
}

/// Генерирует [count] GIS-объектов с уникальными ID.
List<GisObject> generateObjects(int count) {
  return List.generate(count, (i) => GisObject(
    id: 'load_obj_$i',
    name: 'Load Test Object $i',
    description: 'Description for object $i — test data',
    category: _testCategory,
    layers: generateLayers(4, prefix: 'load_obj_$i'),
    updatedAt: DateTime(2024, 1, 1).add(Duration(days: i)),
    icon: Icons.landscape_rounded,
  ));
}

/// Генерирует [count] файлов с уникальными ID.
List<GisFile> generateFiles(int count) {
  final types = FileType.values;
  return List.generate(count, (i) => GisFile(
    id: 'load_file_$i',
    name: 'load_file_$i.${_ext(types[i % types.length])}',
    type: types[i % types.length],
    sizeBytes: (i + 1) * 1024 * 100, // 100 KB * (i+1)
    createdAt: DateTime(2024, 1, 1).add(Duration(days: i)),
    description: 'File description $i',
  ));
}

String _ext(FileType t) => const {
  FileType.image: 'jpg',
  FileType.video: 'mp4',
  FileType.geotiff: 'tif',
  FileType.document: 'pdf',
  FileType.pointcloud: 'las',
  FileType.other: 'bin',
}[t]!;

/// Генерирует [count] атрибутов для таблицы.
List<AttributeProperty> generateProperties(int count) {
  final types = DataType.values;
  return List.generate(count, (i) => AttributeProperty(
    id: 'load_prop_$i',
    name: 'Property $i',
    description: 'Description of property $i',
    measurementUnit: ['м', 'кг', '%', '°C', ''][i % 5],
    dataType: types[i % types.length],
  ));
}

/// Генерирует [count] таблиц атрибутов, каждая с [propsPerTable] свойствами.
List<AttributeTable> generateTables(int count, {int propsPerTable = 10}) {
  return List.generate(count, (i) => AttributeTable(
    id: 'load_tbl_$i',
    name: 'Load Table $i',
    description: 'Generated table #$i',
    properties: generateProperties(propsPerTable),
    updatedAt: DateTime(2024, 1, 1).add(Duration(days: i)),
  ));
}

/// Генерирует FileWithObject для нагрузочного теста.
List<FileWithObject> generateFilesWithObjects(int count) {
  final files = generateFiles(count);
  return files.asMap().entries.map((e) => FileWithObject(
    file: e.value,
    objectId: 'load_obj_${e.key % 50}', // распределяем по 50 объектам
    objectName: 'Object ${e.key % 50}',
    objectIcon: Icons.landscape_rounded,
    objectColor: const Color(0xFF00D4AA),
  )).toList();
}

/// Генерирует MapDemoPoint для нагрузочного теста.
List<MapDemoPoint> generatePoints(int count) {
  return List.generate(count, (i) {
    final x = (i % 100) / 100.0;
    final y = (i ~/ 100) / 100.0;
    return MapDemoPoint(
      x: x.clamp(0.0, 1.0),
      y: y.clamp(0.0, 1.0),
      label: 'P-${i.toString().padLeft(4, '0')}',
      color: const Color(0xFF00D4AA),
    );
  });
}

/// Измеряет время выполнения синхронной функции в миллисекундах.
int measureSyncMs(void Function() fn) {
  final sw = Stopwatch()..start();
  fn();
  sw.stop();
  return sw.elapsedMilliseconds;
}

/// Измеряет время выполнения async-функции в миллисекундах.
Future<int> measureAsyncMs(Future<void> Function() fn) async {
  final sw = Stopwatch()..start();
  await fn();
  sw.stop();
  return sw.elapsedMilliseconds;
}
