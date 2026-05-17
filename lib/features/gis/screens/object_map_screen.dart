// lib/features/gis/screens/object_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../models/app_models.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/common_widgets.dart';

class ObjectMapScreen extends ConsumerStatefulWidget {
  final String objectId;
  final GisObject? initialObject;
  const ObjectMapScreen({super.key, required this.objectId, this.initialObject});

  @override
  ConsumerState<ObjectMapScreen> createState() => _ObjectMapScreenState();
}

class _ObjectMapScreenState extends ConsumerState<ObjectMapScreen> with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _fabAnim;
  GisObject? _object;

  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  double _scaleBase = 1.0;
  int? _selectedPointIndex;

  final List<MapDemoPoint> _demoPoints = [
    const MapDemoPoint(x: 0.25, y: 0.35, label: 'P-01', color: AppColors.layerPoint),
    const MapDemoPoint(x: 0.55, y: 0.45, label: 'P-02', color: AppColors.layerPoint),
    const MapDemoPoint(x: 0.70, y: 0.28, label: 'P-03', color: AppColors.layerPoint),
    const MapDemoPoint(x: 0.40, y: 0.65, label: 'P-04', color: AppColors.layerPoint),
  ];

  @override
  void initState() {
    super.initState();
    _object = widget.initialObject;
    _fabAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..forward();
  }

  @override
  void dispose() { _fabAnim.dispose(); super.dispose(); }

  void _onPointTap(int index) {
    setState(() {
      _selectedPointIndex = _selectedPointIndex == index ? null : index;
    });
  }

  void _editPoint(int index, String? tableId) {
    setState(() => _selectedPointIndex = null);
    showDialog<void>(
      context: context,
      builder: (_) => _PointEditorDialog(
        point: _demoPoints[index],
        tableId: tableId,
        onSave: (updated) => setState(() => _demoPoints[index] = updated),
      ),
    );
  }

  void _deletePoint(int index) {
    setState(() {
      _demoPoints.removeAt(index);
      _selectedPointIndex = null;
    });
  }

  Widget _buildPointPopup(Size mapSize, List<GisLayer> layers) {
    final idx = _selectedPointIndex!;
    if (idx >= _demoPoints.length) return const SizedBox.shrink();
    final p = _demoPoints[idx];

    // Compute screen position after zoom/pan transform (alignment: center).
    final sx = (p.x - 0.5) * mapSize.width  * _zoom + _pan.dx + mapSize.width  / 2;
    final sy = (p.y - 0.5) * mapSize.height * _zoom + _pan.dy + mapSize.height / 2;

    const popupW = 140.0;
    const popupH = 38.0;
    const gap = 14.0;

    final left = (sx - popupW / 2).clamp(8.0, mapSize.width  - popupW - 8.0);
    final top  = (sy - popupH - gap).clamp(8.0, mapSize.height - popupH - 48.0);

    // Use the first visible POINTS layer's tableId for attribute editing.
    final tableId = layers
        .where((l) => l.type.supportsTable && l.tableId != null && l.isVisible)
        .map((l) => l.tableId)
        .firstOrNull;

    return Positioned(
      left: left, top: top, width: popupW,
      child: _PointPopup(
        point: p,
        onEdit: () => _editPoint(idx, tableId),
        onDelete: () => _deletePoint(idx),
      ),
    );
  }

  void _showFiles() {
    ref.read(filesProvider(widget.objectId));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilesSheet(objectId: widget.objectId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layersAsync = ref.watch(layersProvider(widget.objectId));
    final layers = layersAsync.valueOrNull ?? [];
    final isDark = ref.watch(isDarkProvider);
    final iconColor = isDark ? AppColors.textSecondary : AppColors.textSecondaryLight;
    final titleColor = isDark ? AppColors.textPrimary : AppColors.textPrimaryLight;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF0F1520) : AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: (isDark ? AppColors.surfaceDark : AppColors.surfaceLight).withOpacity(0.95),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: iconColor),
          onPressed: () => context.pop()),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_object?.name ?? 'Объект',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: titleColor),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          if (_object != null) Row(children: [
            Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(_object!.category.name, style: TextStyle(fontSize: 11, color: iconColor)),
          ]),
        ]),
        actions: [
          Stack(alignment: Alignment.topRight, children: [
            IconButton(icon: Icon(Icons.attach_file_rounded, color: iconColor), onPressed: _showFiles, tooltip: 'Файлы'),
            Positioned(top: 10, right: 10, child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle))),
          ]),
          IconButton(icon: Icon(Icons.layers_rounded, color: iconColor), onPressed: () => _scaffoldKey.currentState?.openEndDrawer(), tooltip: 'Слои'),
          const SizedBox(width: 6),
        ],
      ),
      endDrawer: _LayersDrawer(objectId: widget.objectId),
      body: LayoutBuilder(builder: (_, constraints) {
        final mapSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_selectedPointIndex != null) setState(() => _selectedPointIndex = null);
              },
              onScaleStart: (d) => _scaleBase = _zoom,
              onScaleUpdate: (d) => setState(() {
                _zoom = (_scaleBase * d.scale).clamp(0.25, 5.0);
                _pan += d.focalPointDelta;
              }),
              child: _MapCanvas(
                layers: layers, isDark: isDark,
                demoPoints: _demoPoints, onPointTap: _onPointTap,
                zoom: _zoom, pan: _pan,
              ),
            ),
            Positioned(right: 14, bottom: 90, child: ScaleTransition(
              scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
              child: _MapControls(
                isDark: isDark,
                onCenter: () => setState(() { _zoom = 1.0; _pan = Offset.zero; }),
                onZoomIn:  () => setState(() => _zoom = (_zoom * 1.5).clamp(0.25, 5.0)),
                onZoomOut: () => setState(() => _zoom = (_zoom / 1.5).clamp(0.25, 5.0)),
              ),
            )),
            if (layersAsync.isLoading)
              const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(AppColors.accent), minHeight: 2)),
            Positioned(bottom: 0, left: 0, right: 0, child: _StatusBar(layers: layers, isDark: isDark)),
            if (_selectedPointIndex != null && _selectedPointIndex! < _demoPoints.length)
              _buildPointPopup(mapSize, layers),
          ],
        );
      }),
    );
  }
}

// ── Map canvas ───────────────────────────────────────────────
class _MapCanvas extends StatelessWidget {
  final List<GisLayer> layers;
  final bool isDark;
  final List<MapDemoPoint> demoPoints;
  final void Function(int) onPointTap;
  final double zoom;
  final Offset pan;
  const _MapCanvas({
    required this.layers, required this.isDark,
    required this.demoPoints, required this.onPointTap,
    this.zoom = 1.0, this.pan = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? AppColors.textMuted : AppColors.textSecondaryLight;
    final bgColor    = isDark ? const Color(0xFF0F1520) : const Color(0xFFF0F4F8);
    final zoomLabel  = '${zoom.toStringAsFixed(1)}×';
    final scaleMeter = (500 / zoom).round().clamp(1, 99999);
    final scaleLabel = scaleMeter >= 1000
        ? '${(scaleMeter / 1000).toStringAsFixed(1)} км'
        : '$scaleMeter м';

    return Stack(children: [
      // Static background — visible when panning near edges.
      Positioned.fill(child: ColoredBox(color: bgColor)),
      // Zoomable + pannable content, clipped to canvas bounds.
      Positioned.fill(child: ClipRect(child: Transform(
        transform: Matrix4.identity()
          ..translate(pan.dx, pan.dy)
          ..scale(zoom),
        alignment: Alignment.center,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter(isDark: isDark))),
          Positioned.fill(child: CustomPaint(painter: _LayersPainter(layers: layers))),
          if (layers.any((l) => l.type == LayerType.points && l.isVisible))
            ...demoPoints.asMap().entries.map((e) => _DemoPoint(
              point: e.value, isDark: isDark, onTap: () => onPointTap(e.key))),
        ]),
      ))),
      // Fixed overlays — do not zoom or pan.
      Positioned(top: 12, left: 14, child: _CoordBadge('55°44\'N  37°36\'E', isDark: isDark)),
      Positioned(top: 12, right: 14, child: _CoordBadge(zoomLabel, isDark: isDark)),
      Positioned(bottom: 48, left: 14, child: _ScaleBar(label: scaleLabel, isDark: isDark)),
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.map_outlined, size: 44, color: mutedColor.withOpacity(0.25)),
        const SizedBox(height: 6),
        Text('MAP PREVIEW', style: TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 3,
            color: mutedColor.withOpacity(0.25), fontWeight: FontWeight.w600)),
      ])),
    ]);
  }
}

class _GridPainter extends CustomPainter {
  final bool isDark;
  const _GridPainter({required this.isDark});
  @override
  void paint(Canvas c, Size s) {
    final bg    = isDark ? const Color(0xFF0F1520) : const Color(0xFFF0F4F8);
    final fine  = isDark ? const Color(0xFF1A2233) : AppColors.borderLight;
    final major = isDark ? const Color(0xFF1E2B40) : const Color(0xFFC8D0DC);
    c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height), Paint()..color = bg);
    final p = Paint()..color = fine..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 40) c.drawLine(Offset(x, 0), Offset(x, s.height), p);
    for (double y = 0; y < s.height; y += 40) c.drawLine(Offset(0, y), Offset(s.width, y), p);
    final p2 = Paint()..color = major..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 160) c.drawLine(Offset(x, 0), Offset(x, s.height), p2);
    for (double y = 0; y < s.height; y += 160) c.drawLine(Offset(0, y), Offset(s.width, y), p2);
  }
  @override bool shouldRepaint(_GridPainter o) => o.isDark != isDark;
}

class _LayersPainter extends CustomPainter {
  final List<GisLayer> layers;
  const _LayersPainter({required this.layers});
  bool get _area  => layers.any((l) => l.type == LayerType.area       && l.isVisible);
  bool get _ortho => layers.any((l) => l.type == LayerType.orthophoto && l.isVisible);
  @override
  void paint(Canvas c, Size s) {
    if (_area) {
      final vs = [Offset(.20*s.width,.25*s.height),Offset(.65*s.width,.20*s.height),Offset(.75*s.width,.55*s.height),Offset(.55*s.width,.75*s.height),Offset(.15*s.width,.65*s.height)];
      final path = Path()..moveTo(vs[0].dx,vs[0].dy);
      for (final v in vs.skip(1)) path.lineTo(v.dx,v.dy);
      path.close();
      c.drawPath(path, Paint()..color = AppColors.layerPolygon.withOpacity(0.08)..style = PaintingStyle.fill);
      c.drawPath(path, Paint()..color = AppColors.layerPolygon.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
    if (_ortho) {
      final r = Rect.fromLTWH(.10*s.width, .15*s.height, .80*s.width, .70*s.height);
      c.drawRect(r, Paint()..color = AppColors.layerRaster.withOpacity(0.06)..style = PaintingStyle.fill);
      c.drawRect(r, Paint()..color = AppColors.layerRaster.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1);
    }
  }
  @override bool shouldRepaint(_LayersPainter o) => o._area != _area || o._ortho != _ortho;
}

class _DemoPoint extends StatelessWidget {
  final MapDemoPoint point;
  final bool isDark;
  final VoidCallback onTap;
  const _DemoPoint({required this.point, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: LayoutBuilder(builder: (_, c) => Stack(children: [
      Positioned(
        left: point.x*c.maxWidth-14, top: point.y*c.maxHeight-14,
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(width: 28, height: 28, child: Center(
            child: Container(width: 10, height: 10,
              decoration: BoxDecoration(color: point.color, shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
                boxShadow: [BoxShadow(color: point.color.withOpacity(0.5), blurRadius: 5)])))))),
      Positioned(left: point.x*c.maxWidth+7, top: point.y*c.maxHeight-8,
        child: IgnorePointer(child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: isDark ? AppColors.bgDark.withOpacity(0.8) : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: point.color.withOpacity(0.4))),
          child: Text(point.label, style: TextStyle(fontSize: 8, color: point.color, fontFamily: 'monospace', fontWeight: FontWeight.w700))))),
    ])),
  );
}

class _CoordBadge extends StatelessWidget {
  final String t;
  final bool isDark;
  const _CoordBadge(this.t, {required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: isDark ? AppColors.bgDark.withOpacity(0.75) : Colors.white.withOpacity(0.85),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
    child: Text(t, style: TextStyle(fontSize: 10,
      color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
      fontFamily: 'monospace')));
}

class _ScaleBar extends StatelessWidget {
  final bool isDark;
  final String label;
  const _ScaleBar({required this.isDark, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: isDark ? AppColors.bgDark.withOpacity(0.75) : Colors.white.withOpacity(0.85),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 50, height: 2,
        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 9,
        color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
        fontFamily: 'monospace')),
    ]));
}

// ── Map controls ─────────────────────────────────────────────
class _MapControls extends StatelessWidget {
  final VoidCallback onCenter, onZoomIn, onZoomOut;
  final bool isDark;
  const _MapControls({required this.onCenter, required this.onZoomIn, required this.onZoomOut, required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: (isDark ? AppColors.surfaceDark : Colors.white).withOpacity(0.92),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), blurRadius: 12, offset: const Offset(0, 4))]),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _MBtn(Icons.my_location_rounded, onCenter, isDark: isDark),
      Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
      _MBtn(Icons.add_rounded, onZoomIn, isDark: isDark),
      Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
      _MBtn(Icons.remove_rounded, onZoomOut, isDark: isDark),
    ]));
}

class _MBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  const _MBtn(this.icon, this.onTap, {required this.isDark});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(13),
    child: SizedBox(width: 42, height: 42,
      child: Icon(icon, size: 18, color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight)));
}

// ── Status bar ───────────────────────────────────────────────
class _StatusBar extends StatelessWidget {
  final List<GisLayer> layers;
  final bool isDark;
  const _StatusBar({required this.layers, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final vis = layers.where((l) => l.isVisible).toList();
    final mutedColor = isDark ? AppColors.textMuted : AppColors.textSecondaryLight;
    final bgColor    = isDark ? AppColors.bgDark    : AppColors.bgLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
        colors: [bgColor.withOpacity(0.9), Colors.transparent])),
      child: Row(children: [
        Icon(Icons.layers_rounded, size: 13, color: mutedColor),
        const SizedBox(width: 5),
        Text('${vis.length}/${layers.length} слоёв',
          style: TextStyle(fontSize: 10, color: mutedColor, fontFamily: 'monospace')),
        const Spacer(),
        ...vis.take(5).map((l) => Container(width: 7, height: 7, margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(color: l.color, shape: BoxShape.circle))),
      ]),
    );
  }
}

// ── Layers drawer ────────────────────────────────────────────
class _LayersDrawer extends ConsumerWidget {
  final String objectId;
  const _LayersDrawer({required this.objectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(layersProvider(objectId));
    return Drawer(
      child: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(18, 14, 10, 8), child: Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.layers_rounded, size: 16, color: AppColors.accent)),
            const SizedBox(width: 10),
            const Text('Слои', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close_rounded, size: 17, color: AppColors.textMuted), onPressed: () => Navigator.pop(context)),
          ])),
          Divider(height: 1, color: AppColors.dividerDark),
          Expanded(child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error))),
            data: (layers) => ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: layers.length,
              separatorBuilder: (_, __) => Divider(height: 1, indent: 50, color: AppColors.dividerDark),
              itemBuilder: (_, i) => _LayerTile(layer: layers[i], objectId: objectId),
            ),
          )),
          Divider(height: 1, color: AppColors.dividerDark),
          Padding(padding: const EdgeInsets.all(14),
            child: OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _CreateLayerDialog(objectId: objectId),
              ),
              icon: const Icon(Icons.add_rounded, size: 16), label: const Text('Добавить слой'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.accentDim),
                minimumSize: const Size(double.infinity, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))))),
        ]),
      ),
    );
  }
}

class _LayerTile extends ConsumerWidget {
  final GisLayer layer;
  final String objectId;
  const _LayerTile({required this.layer, required this.objectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 9, height: 9,
              decoration: BoxDecoration(color: layer.isVisible ? layer.color : AppColors.textMuted, shape: BoxShape.circle,
                boxShadow: layer.isVisible ? [BoxShadow(color: layer.color.withOpacity(0.4), blurRadius: 5)] : [])),
            const SizedBox(width: 10),
            Icon(layer.type.icon, size: 13, color: layer.isVisible ? layer.type.color : AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(layer.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: layer.isVisible ? AppColors.textPrimary : AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
            InkWell(
              onTap: () => ref.read(layersProvider(objectId).notifier).toggleVisibility(layer.id),
              borderRadius: BorderRadius.circular(5),
              child: Padding(padding: const EdgeInsets.all(4),
                child: Icon(layer.isVisible ? Icons.visibility_rounded : Icons.visibility_off_outlined,
                  size: 18, color: layer.isVisible ? AppColors.accent : AppColors.textMuted))),
          ]),
          Padding(padding: const EdgeInsets.only(left: 19),
            child: Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: layer.type.color.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                child: Text(layer.type.label, style: TextStyle(fontSize: 9, color: layer.type.color, fontWeight: FontWeight.w600))),
              const SizedBox(width: 5),
              Text('${layer.objectsCount} obj', style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'monospace')),
              const Spacer(),
              if (layer.type.supportsTable && layer.tableId != null)
                _SmBtn(Icons.table_rows_outlined, () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  router.go('/tables/${layer.tableId}', extra: objectId);
                }),
              _SmBtn(Icons.edit_outlined, () => showAppSnackbar(context, 'Редактировать: ${layer.name}')),
              _SmBtn(Icons.delete_outline_rounded, () => ref.read(layersProvider(objectId).notifier).deleteLayer(layer.id), color: AppColors.error),
            ])),
        ],
      ),
    );
  }
}

class _SmBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color color;
  const _SmBtn(this.icon, this.onTap, {this.color = AppColors.textMuted});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(5),
    child: Padding(padding: const EdgeInsets.all(3), child: Icon(icon, size: 14, color: color)));
}

// ── Files bottom sheet ────────────────────────────────────────
class _FilesSheet extends ConsumerWidget {
  final String objectId;
  const _FilesSheet({required this.objectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(filesProvider(objectId));
    return DraggableScrollableSheet(
      initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 9, bottom: 4), width: 34, height: 4,
            decoration: BoxDecoration(color: AppColors.borderDark, borderRadius: BorderRadius.circular(2)))),
          Padding(padding: const EdgeInsets.fromLTRB(18, 8, 14, 12), child: Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.layerPolygon.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.layerPolygon)),
            const SizedBox(width: 10),
            const Text('Файлы объекта', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showAddOptions(context, objectId),
              icon: const Icon(Icons.add_rounded, size: 15), label: const Text('Добавить'),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent, textStyle: const TextStyle(fontSize: 12))),
          ])),
          Divider(height: 1, color: AppColors.dividerDark),
          Expanded(child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
            error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.error))),
            data: (files) => ListView.separated(
              controller: ctrl, padding: const EdgeInsets.only(bottom: 20),
              itemCount: files.length,
              separatorBuilder: (_, __) => Divider(height: 1, indent: 66, color: AppColors.dividerDark),
              itemBuilder: (_, i) {
                final f = files[i];
                return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: f.type.color.withOpacity(0.1), borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: f.type.color.withOpacity(0.25))), child: Icon(f.type.icon, color: f.type.color, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: f.type.color.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                        child: Text(f.type.label, style: TextStyle(fontSize: 9, color: f.type.color, fontWeight: FontWeight.w600))),
                      const SizedBox(width: 6),
                      Text(f.sizeLabel, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'monospace')),
                    ]),
                  ])),
                  IconButton(icon: const Icon(Icons.download_outlined, size: 17, color: AppColors.textMuted),
                    onPressed: () => showAppSnackbar(context, 'Скачивание: ${f.name}', icon: Icons.download_rounded)),
                ]));
              },
            ),
          )),
        ]),
      ),
    );
  }
}

// ── Create Layer dialog ───────────────────────────────────────
class _CreateLayerDialog extends ConsumerStatefulWidget {
  final String objectId;
  const _CreateLayerDialog({required this.objectId});
  @override
  ConsumerState<_CreateLayerDialog> createState() => _CreateLayerDialogState();
}

class _CreateLayerDialogState extends ConsumerState<_CreateLayerDialog> {
  final _nameCtrl = TextEditingController();
  LayerType _type = LayerType.area;
  String? _selectedTableId;
  String? _selectedFileId;
  bool _saving = false;
  bool _triedSubmit = false;

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() => _triedSubmit = true);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    if (_type.supportsTable && _selectedTableId == null) return;
    if (_type.requiresFile  && _selectedFileId  == null) return;
    setState(() => _saving = true);
    final layer = GisLayer(
      id: '${widget.objectId}_l${DateTime.now().millisecondsSinceEpoch}',
      name: name, type: _type, color: _type.color,
      isVisible: true, objectsCount: 0,
      tableId: _type.supportsTable ? _selectedTableId : null,
      fileId:  _type.requiresFile  ? _selectedFileId  : null,
    );
    await ref.read(layersProvider(widget.objectId).notifier).addLayer(layer);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tables = ref.watch(tablesProvider).valueOrNull ?? [];
    final geotiffFiles = ref.watch(globalFilesProvider)
        .where((f) => f.type == FileType.geotiff).toList();

    return AlertDialog(
      title: const Text('Новый слой', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Название',
            labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<LayerType>(
          value: _type,
          items: LayerType.values.map((t) => DropdownMenuItem(
            value: t,
            child: Row(children: [
              Icon(t.icon, size: 13, color: t.color),
              const SizedBox(width: 8),
              Text(t.label, style: const TextStyle(fontSize: 13)),
            ]),
          )).toList(),
          onChanged: (v) => setState(() {
            _type = v!;
            _selectedTableId = null;
            _selectedFileId  = null;
            _triedSubmit = false;
          }),
          decoration: const InputDecoration(
            labelText: 'Тип',
            labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        if (_type.supportsTable) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedTableId,
            hint: const Text('Выберите таблицу', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            items: tables.map((t) => DropdownMenuItem(
              value: t.id,
              child: Text(t.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (v) => setState(() => _selectedTableId = v),
            decoration: InputDecoration(
              labelText: 'Таблица атрибутов *',
              labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              errorText: _triedSubmit && _selectedTableId == null ? 'Выберите таблицу' : null,
            ),
          ),
        ],
        if (_type.requiresFile) ...[
          const SizedBox(height: 12),
          if (geotiffFiles.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                SizedBox(width: 8),
                Expanded(child: Text('Нет .tif файлов в хранилище',
                    style: TextStyle(fontSize: 12, color: AppColors.error))),
              ]),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedFileId,
              hint: const Text('Выберите файл', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              items: geotiffFiles.map((f) => DropdownMenuItem(
                value: f.id,
                child: Text(f.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setState(() => _selectedFileId = v),
              decoration: InputDecoration(
                labelText: 'Ортофотоплан (.tif) *',
                labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                errorText: _triedSubmit && _selectedFileId == null ? 'Выберите файл' : null,
              ),
            ),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Добавить'),
        ),
      ],
    );
  }
}

// ── Point popup (Edit / Delete buttons above the point) ────────
class _PointPopup extends StatelessWidget {
  final MapDemoPoint point;
  final VoidCallback onEdit, onDelete;
  const _PointPopup({required this.point, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderDark),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7,
            decoration: BoxDecoration(color: point.color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: point.color.withOpacity(0.5), blurRadius: 4)])),
          const SizedBox(width: 6),
          Text(point.label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          InkWell(onTap: onEdit, borderRadius: BorderRadius.circular(4),
            child: const Padding(padding: EdgeInsets.all(3),
              child: Icon(Icons.edit_outlined, size: 14, color: AppColors.accent))),
          const SizedBox(width: 1),
          InkWell(onTap: onDelete, borderRadius: BorderRadius.circular(4),
            child: Padding(padding: const EdgeInsets.all(3),
              child: Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.error))),
        ]),
      ),
    );
  }
}

// ── Point editor (dynamic fields from linked table) ────────────
class _PointEditorDialog extends ConsumerStatefulWidget {
  final MapDemoPoint point;
  final String? tableId;
  final ValueChanged<MapDemoPoint> onSave;
  const _PointEditorDialog({required this.point, required this.tableId, required this.onSave});
  @override
  ConsumerState<_PointEditorDialog> createState() => _PointEditorDialogState();
}

class _PointEditorDialogState extends ConsumerState<_PointEditorDialog> {
  late final TextEditingController _labelCtrl;
  // Controllers keyed by AttributeProperty.id, created lazily in build.
  final Map<String, TextEditingController> _attrCtrls = {};

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.point.label);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    for (final c in _attrCtrls.values) c.dispose();
    super.dispose();
  }

  void _save(List<AttributeProperty> props) {
    final newAttrs = Map<String, String>.from(widget.point.attributes);
    for (final p in props) {
      newAttrs[p.id] = _attrCtrls[p.id]?.text.trim() ?? '';
    }
    final label = _labelCtrl.text.trim();
    widget.onSave(widget.point.copyWith(
      label: label.isNotEmpty ? label : widget.point.label,
      attributes: newAttrs,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tables = ref.watch(tablesProvider).valueOrNull ?? [];
    final table = widget.tableId != null
        ? tables.where((t) => t.id == widget.tableId).firstOrNull
        : null;
    final props = table?.properties ?? [];

    // Lazily create a controller per property (idempotent: putIfAbsent).
    for (final p in props) {
      _attrCtrls.putIfAbsent(p.id,
          () => TextEditingController(text: widget.point.attributes[p.id] ?? ''));
    }

    final lat = (55.0 + widget.point.y * 2).toStringAsFixed(5);
    final lon = (37.0 + widget.point.x * 2).toStringAsFixed(5);

    return AlertDialog(
      title: Row(children: [
        Container(width: 9, height: 9,
          decoration: BoxDecoration(color: widget.point.color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: widget.point.color.withOpacity(0.5), blurRadius: 5)])),
        const SizedBox(width: 8),
        Text(widget.point.label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ]),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Coordinates badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.location_on_rounded, size: 13, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('$lat°N  $lon°E',
                  style: const TextStyle(fontSize: 11, color: AppColors.accent, fontFamily: 'monospace')),
              ]),
            ),
            const SizedBox(height: 12),
            // Label field (always shown)
            TextField(
              controller: _labelCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Метка',
                labelStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            // Dynamic attribute fields from the linked table
            if (props.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.dividerDark),
              const SizedBox(height: 10),
              Text(table!.name.toUpperCase(),
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                    letterSpacing: 0.8, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              ...props.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _attrCtrls[p.id],
                  keyboardType: p.dataType == DataType.integer
                      ? TextInputType.number
                      : p.dataType == DataType.double_
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: p.measurementUnit.isNotEmpty
                        ? '${p.name} (${p.measurementUnit})'
                        : p.name,
                    hintText: p.description,
                    labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
              )),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        ElevatedButton(
          onPressed: () => _save(props),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

// ── Add file: choice sheet ────────────────────────────────────

void _showAddOptions(BuildContext ctx, String objectId) {
  showModalBottomSheet<void>(
    context: ctx,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _AddOptionsSheet(objectId: objectId, parentCtx: ctx),
  );
}

class _AddOptionsSheet extends StatelessWidget {
  final String objectId;
  final BuildContext parentCtx;
  const _AddOptionsSheet({required this.objectId, required this.parentCtx});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 34, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.borderDark, borderRadius: BorderRadius.circular(2)))),
        const Text('Добавить файл',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        _OptionTile(
          icon: Icons.folder_outlined,
          color: AppColors.layerPolygon,
          title: 'Выбрать из хранилища',
          subtitle: 'Прикрепить существующий файл',
          onTap: () {
            Navigator.pop(context);
            showModalBottomSheet<void>(
              context: parentCtx,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _StoragePickerSheet(objectId: objectId),
            );
          },
        ),
        const SizedBox(height: 10),
        _OptionTile(
          icon: Icons.upload_rounded,
          color: AppColors.layerPoint,
          title: 'Загрузить новый файл',
          subtitle: 'Выбрать из галереи или файлов',
          onTap: () {
            Navigator.pop(context);
            _showUploadPlaceholder(parentCtx);
          },
        ),
      ]),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.color, required this.title,
      required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.cardDark,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderDark)),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
        ]),
      ),
    ),
  );
}

// ── Storage picker sheet ──────────────────────────────────────

class _StoragePickerSheet extends ConsumerWidget {
  final String objectId;
  const _StoragePickerSheet({required this.objectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(globalFilesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6, minChildSize: 0.35, maxChildSize: 0.92, expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Center(child: Container(margin: const EdgeInsets.only(top: 9, bottom: 4), width: 34, height: 4,
            decoration: BoxDecoration(color: AppColors.borderDark, borderRadius: BorderRadius.circular(2)))),
          Padding(padding: const EdgeInsets.fromLTRB(18, 8, 10, 12), child: Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.storage_rounded, size: 16, color: AppColors.accent)),
            const SizedBox(width: 10),
            const Text('Выбрать из хранилища',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close_rounded, size: 17, color: AppColors.textMuted),
              onPressed: () => Navigator.pop(context)),
          ])),
          Divider(height: 1, color: AppColors.dividerDark),
          Expanded(child: files.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.storage_rounded, size: 40, color: AppColors.textMuted.withOpacity(0.4)),
                const SizedBox(height: 12),
                const Text('Хранилище пустое',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                const Text('Добавьте файлы через раздел «Файлы»',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted), textAlign: TextAlign.center),
              ])))
            : ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: files.length,
                separatorBuilder: (_, __) => Divider(height: 1, indent: 70, color: AppColors.dividerDark),
                itemBuilder: (_, i) {
                  final f = files[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(width: 42, height: 42,
                      decoration: BoxDecoration(color: f.type.color.withOpacity(0.1), borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: f.type.color.withOpacity(0.25))),
                      child: Icon(f.type.icon, color: f.type.color, size: 20)),
                    title: Text(f.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: f.type.color.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                        child: Text(f.type.label, style: TextStyle(fontSize: 9, color: f.type.color, fontWeight: FontWeight.w600))),
                      const SizedBox(width: 6),
                      Text(f.sizeLabel, style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'monospace')),
                    ]),
                    trailing: const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.accent),
                    onTap: () {
                      ref.read(repoProvider).attachFileToObject(objectId, f);
                      ref.invalidate(filesProvider(objectId));
                      final sm = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      sm.showSnackBar(SnackBar(
                        content: Row(children: [
                          const Icon(Icons.attach_file_rounded, color: AppColors.accent, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text('«${f.name}» прикреплён',
                              style: const TextStyle(fontWeight: FontWeight.w500))),
                        ]),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 3),
                      ));
                    },
                  );
                },
              )),
        ]),
      ),
    );
  }
}

// ── Upload placeholder ────────────────────────────────────────

void _showUploadPlaceholder(BuildContext ctx) {
  showDialog<void>(
    context: ctx,
    builder: (dCtx) => AlertDialog(
      backgroundColor: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      title: const Text('Загрузить файл',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 56, height: 56,
          decoration: BoxDecoration(color: AppColors.accentSurface, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.upload_rounded, color: AppColors.accent, size: 28)),
        const SizedBox(height: 14),
        const Text(
          'Загрузка файлов из галереи будет реализована в следующей версии.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          textAlign: TextAlign.center),
      ]),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dCtx),
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bgDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );
}
