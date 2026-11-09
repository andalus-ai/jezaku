import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ar_engine/ar_engine.dart';

void main() => runApp(const ARExampleApp());

// ─── App ──────────────────────────────────────────────────────────────────────

class ARExampleApp extends StatelessWidget {
  const ARExampleApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AR Engine Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00E5FF), secondary: Color(0xFF7C4DFF)),
        ),
        home: const _HomeScreen(),
      );
}

// ─── Home ─────────────────────────────────────────────────────────────────────

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AR Engine',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  SizedBox(height: 4),
                  Text('Multi-platform Augmented Reality',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ]),
          ),
          Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
            _tile(context, 'Place & Animate Objects', Icons.view_in_ar,
                () => _push(context, const PlaceObjectsScreen())),
            _tile(context, 'Physics Sandbox', Icons.science,
                () => _push(context, const PhysicsSandboxScreen())),
            _tile(context, 'Measurement Tool', Icons.straighten,
                () => _push(context, const MeasurementScreen())),
            _tile(context, 'Gesture Interaction', Icons.touch_app,
                () => _push(context, const GestureScreen())),
            _tile(context, 'Color Animations', Icons.palette,
                () => _push(context, const ColorAnimScreen())),
            _tile(context, 'Snapshot & Share', Icons.photo_camera,
                () => _push(context, const SnapshotScreen())),
            _tile(context, 'Debug Overlay', Icons.bug_report,
                () => _push(context, const DebugScreen())),
          ])),
        ])),
      );

  void _push(BuildContext ctx, Widget w) =>
      Navigator.push(ctx, MaterialPageRoute<void>(builder: (_) => w));

  Widget _tile(
          BuildContext ctx, String label, IconData icon, VoidCallback onTap) =>
      Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: const Color(0xFF00E5FF).withOpacity(0.15),
                  child: Icon(icon, color: const Color(0xFF00E5FF))),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right),
              onTap: onTap));
}

// ─── Shared AR scaffold ───────────────────────────────────────────────────────

class _ARBase extends StatefulWidget {
  final String title;
  final Widget Function(ARController, BuildContext) content;
  const _ARBase({required this.title, required this.content});
  @override
  State<_ARBase> createState() => _ARBaseState();
}

class _ARBaseState extends State<_ARBase> {
  ARController? _ctrl;

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(widget.title), backgroundColor: Colors.black54),
        body: Stack(children: [
          ARWidget(
            config: const ARSessionConfig(
                detectHorizontalPlanes: true, lightingEstimationEnabled: true),
            onARViewCreated: (c) => setState(() => _ctrl = c),
            loadingWidget: const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Starting AR…', style: TextStyle(color: Colors.white70)),
            ])),
            errorBuilder: (ctx, err) => Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text('$err',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white60)),
                    ]))),
          ),
          if (_ctrl != null) widget.content(_ctrl!, context),
        ]),
      );
}

// ─── Demo 1: Place & Animate Objects ─────────────────────────────────────────

class PlaceObjectsScreen extends StatefulWidget {
  const PlaceObjectsScreen({super.key});
  @override
  State<PlaceObjectsScreen> createState() => _PlaceState();
}

class _PlaceState extends State<PlaceObjectsScreen> {
  ARSceneManager? _scene;
  ARPrimitiveShape _shape = ARPrimitiveShape.cube;
  final _rng = math.Random();
  int _count = 0;
  int _colorIdx = 0;

  static const _colors = [
    ARMaterialColor(r: 0.2, g: 0.6, b: 1),
    ARMaterialColor(r: 1, g: 0.3, b: 0.2),
    ARMaterialColor(r: 0.2, g: 1, b: 0.4),
    ARMaterialColor(r: 1, g: 0.8, b: 0),
    ARMaterialColor(r: 0.7, g: 0.2, b: 1),
  ];

  @override
  Widget build(BuildContext context) => _ARBase(
        title: 'Place Objects',
        content: (ctrl, ctx) {
          _scene ??= ARSceneManager(ctrl);
          return Column(children: [
            const Spacer(),
            // Shape selector
            SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    ARPrimitiveShape.cube,
                    ARPrimitiveShape.sphere,
                    ARPrimitiveShape.cylinder,
                    ARPrimitiveShape.capsule
                  ]
                      .map((s) => GestureDetector(
                          onTap: () => setState(() => _shape = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                                color: _shape == s
                                    ? const Color(0xFF00E5FF)
                                    : Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _shape == s
                                        ? const Color(0xFF00E5FF)
                                        : Colors.white24)),
                            child: Text(s.name,
                                style: TextStyle(
                                    color: _shape == s
                                        ? Colors.black
                                        : Colors.white70,
                                    fontSize: 13)),
                          )))
                      .toList(),
                )),
            const SizedBox(height: 8),
            // Color + action row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                ..._colors.asMap().entries.map((e) => GestureDetector(
                    onTap: () => setState(() => _colorIdx = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 6),
                      width: _colorIdx == e.key ? 32 : 24,
                      height: _colorIdx == e.key ? 32 : 24,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.fromRGBO(
                              (e.value.r * 255).round(),
                              (e.value.g * 255).round(),
                              (e.value.b * 255).round(),
                              1),
                          border: Border.all(
                              color: _colorIdx == e.key
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2.5)),
                    ))),
                const Spacer(),
                Text('$_count placed',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FloatingActionButton.extended(
                heroTag: 'place',
                onPressed: () async {
                  final hits = await ctrl.hitTest(0.5, 0.6);
                  if (hits.isEmpty || !mounted) return;
                  final node = ARNode(
                    id: 'obj_${DateTime.now().millisecondsSinceEpoch}',
                    primitiveShape: _shape,
                    scale: ARVector3.one() * (0.06 + _rng.nextDouble() * 0.03),
                    material: ARMaterial(
                        baseColor: _colors[_colorIdx],
                        metallic: _rng.nextDouble() * 0.5,
                        roughness: 0.3 + _rng.nextDouble() * 0.5),
                  );
                  final entity =
                      await _scene!.placeEntity(node: node, at: hits.first);
                  _scene!.hover(entity.id,
                      amplitude: 0.012, period: 1.5 + _rng.nextDouble());
                  if (mounted) setState(() => _count++);
                },
                label: const Text('Place'),
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 12),
              FloatingActionButton(
                heroTag: 'clear',
                mini: true,
                onPressed: () {
                  _scene?.clearAll();
                  setState(() => _count = 0);
                },
                backgroundColor: Colors.grey[800],
                child: const Icon(Icons.delete_sweep),
              ),
            ]),
            const SizedBox(height: 32),
          ]);
        },
      );
}

// ─── Demo 2: Physics Sandbox ──────────────────────────────────────────────────

class PhysicsSandboxScreen extends StatefulWidget {
  const PhysicsSandboxScreen({super.key});
  @override
  State<PhysicsSandboxScreen> createState() => _PhysicsState();
}

class _PhysicsState extends State<PhysicsSandboxScreen> {
  ARSceneManager? _scene;
  final _rng = math.Random();
  int _count = 0;

  Future<void> _spawn(ARController ctrl) async {
    _scene ??= ARSceneManager(ctrl);
    final x = (_rng.nextDouble() - 0.5) * 0.3;
    final shape = [
      ARPrimitiveShape.sphere,
      ARPrimitiveShape.cube,
      ARPrimitiveShape.cylinder
    ][_rng.nextInt(3)];
    final node = ARNode(
      id: 'phys_${DateTime.now().millisecondsSinceEpoch}',
      position: ARVector3(x, 0.5, -0.8),
      scale: ARVector3.one() * (0.045 + _rng.nextDouble() * 0.04),
      primitiveShape: shape,
      material: ARMaterial(
          baseColor: ARMaterialColor(
              r: _rng.nextDouble(), g: _rng.nextDouble(), b: _rng.nextDouble()),
          metallic: _rng.nextDouble() * 0.7,
          roughness: 0.3 + _rng.nextDouble() * 0.5),
    );
    final entity = await _scene!.addFreeEntity(node);
    _scene!.physicsWorld.addBody(ARPhysicsBody(
      nodeId: entity.id,
      initialPosition: node.position,
      mass: 0.2 + _rng.nextDouble(),
      restitution: 0.3 + _rng.nextDouble() * 0.4,
      friction: 0.45,
    ));
    if (mounted) setState(() => _count++);
  }

  @override
  Widget build(BuildContext context) => _ARBase(
        title: 'Physics Sandbox',
        content: (ctrl, ctx) => Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_count objects',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    FloatingActionButton.extended(
                        heroTag: 'spawn',
                        onPressed: () => _spawn(ctrl),
                        label: const Text('Spawn'),
                        icon: const Icon(Icons.add_box)),
                    const SizedBox(width: 10),
                    FloatingActionButton.extended(
                        heroTag: 'explode',
                        backgroundColor: Colors.deepOrange,
                        onPressed: () => _scene?.explode(
                            epicentre: const ARVector3(0, -0.3, -0.8),
                            force: 5,
                            radius: 1),
                        label: const Text('Explode!'),
                        icon: const Icon(Icons.local_fire_department)),
                    const SizedBox(width: 10),
                    FloatingActionButton(
                        heroTag: 'clear',
                        mini: true,
                        backgroundColor: Colors.grey[800],
                        onPressed: () {
                          _scene?.clearAll();
                          setState(() => _count = 0);
                        },
                        child: const Icon(Icons.delete)),
                  ]),
                ],
              )),
        ),
      );
}

// ─── Demo 3: Measurement ─────────────────────────────────────────────────────

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});
  @override
  State<MeasurementScreen> createState() => _MeasureState();
}

class _MeasureState extends State<MeasurementScreen> {
  ARMeasurementTool? _tool;
  ARMeasurementMode _mode = ARMeasurementMode.distance;
  ARMeasurementUnit _unit = ARMeasurementUnit.metric;
  String _result = '—';
  String? _json;

  @override
  Widget build(BuildContext context) => _ARBase(
        title: 'Measurement',
        content: (ctrl, ctx) {
          _tool ??= ARMeasurementTool(ctrl, mode: _mode, unit: _unit);
          return Column(children: [
            // Mode selector
            Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Expanded(
                      child: SegmentedButton<ARMeasurementMode>(
                    selected: {_mode},
                    onSelectionChanged: (s) {
                      setState(() {
                        _mode = s.first;
                        _tool?.mode = _mode;
                        _result = '—';
                      });
                      _tool?.reset();
                    },
                    segments: const [
                      ButtonSegment(
                          value: ARMeasurementMode.distance,
                          label: Text('Dist')),
                      ButtonSegment(
                          value: ARMeasurementMode.area, label: Text('Area')),
                      ButtonSegment(
                          value: ARMeasurementMode.angle, label: Text('Angle')),
                    ],
                  )),
                  const SizedBox(width: 8),
                  // Unit toggle
                  OutlinedButton(
                      onPressed: () => setState(() {
                            _unit = _unit == ARMeasurementUnit.metric
                                ? ARMeasurementUnit.imperial
                                : ARMeasurementUnit.metric;
                            _tool?.unit = _unit;
                            final s = _tool?.currentSession;
                            if (s != null) _result = s.summaryText;
                          }),
                      child:
                          Text(_unit == ARMeasurementUnit.metric ? 'm' : 'ft')),
                ])),
            const Spacer(),
            // Result card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_result,
                    style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 6),
                Text('${_tool?.pointCount ?? 0} points',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 12)),
                if (_json != null) ...[
                  const SizedBox(height: 8),
                  Text('JSON exported ✓',
                      style: TextStyle(
                          color: Colors.greenAccent[200], fontSize: 11)),
                ],
              ]),
            ),
            // Controls
            Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                        onPressed: () async {
                          await _tool?.addPoint(0.5, 0.6);
                          final s = _tool?.currentSession;
                          if (s != null && mounted)
                            setState(() => _result = s.summaryText);
                        },
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Add Point')),
                    ElevatedButton.icon(
                        onPressed: () async {
                          await _tool?.undoLastPoint();
                          final s = _tool?.currentSession;
                          if (mounted)
                            setState(() => _result = s?.summaryText ?? '—');
                        },
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800])),
                    ElevatedButton.icon(
                        onPressed: () {
                          final j = _tool?.exportJSON();
                          if (j != null && mounted)
                            setState(() => _json = j.toString());
                        },
                        icon: const Icon(Icons.code),
                        label: const Text('Export JSON'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[700])),
                    ElevatedButton.icon(
                        onPressed: () async {
                          await _tool?.reset();
                          if (mounted)
                            setState(() {
                              _result = '—';
                              _json = null;
                            });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800])),
                  ],
                )),
          ]);
        },
      );
}

// ─── Demo 4: Gesture Interaction ─────────────────────────────────────────────

class GestureScreen extends StatefulWidget {
  const GestureScreen({super.key});
  @override
  State<GestureScreen> createState() => _GestureState();
}

class _GestureState extends State<GestureScreen> {
  ARSceneManager? _scene;
  String _lastGesture = 'none';
  int _tapCount = 0;

  @override
  Widget build(BuildContext context) => _ARBase(
        title: 'Gesture Interaction',
        content: (ctrl, ctx) {
          _scene ??= ARSceneManager(ctrl);
          return Stack(children: [
            // Gesture handler wraps the full screen
            ARGestureHandler(
              controller: ctrl,
              sceneManager: _scene!,
              autoTransform: true,
              onGesture: (event) {
                if (!mounted) return;
                setState(() {
                  _lastGesture = '${event.type.name}'
                      '${event.entityId != null ? ' → ${event.entityId}' : ''}';
                  if (event.type == ARGestureType.tap) _tapCount++;
                });
              },
              child: const SizedBox.expand(),
            ),
            // HUD
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(14)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Gesture: $_lastGesture',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13)),
                  Text('Taps: $_tapCount',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 10),
                  FloatingActionButton.extended(
                      heroTag: 'spawn_gesture',
                      onPressed: () async {
                        final hits = await ctrl.hitTest(0.5, 0.6);
                        if (hits.isEmpty || !mounted) return;
                        final node = ARNode(
                          id: 'g_${DateTime.now().millisecondsSinceEpoch}',
                          primitiveShape: ARPrimitiveShape.cube,
                          scale: const ARVector3(0.1, 0.1, 0.1),
                          material: const ARMaterial(
                              baseColor: ARMaterialColor(r: 0.2, g: 0.6, b: 1)),
                        );
                        await _scene!.placeEntity(node: node, at: hits.first);
                      },
                      label: const Text('Place Draggable'),
                      icon: const Icon(Icons.add)),
                ]),
              ),
            ),
          ]);
        },
      );
}

// ─── Demo 5: Color Animations ─────────────────────────────────────────────────

class ColorAnimScreen extends StatefulWidget {
  const ColorAnimScreen({super.key});
  @override
  State<ColorAnimScreen> createState() => _ColorAnimState();
}

class _ColorAnimState extends State<ColorAnimScreen> {
  ARSceneManager? _scene;
  String? _activeEntityId;
  String _status = 'Place a sphere, then animate its color';

  @override
  Widget build(BuildContext context) => _ARBase(
        title: 'Color Animations',
        content: (ctrl, ctx) {
          _scene ??= ARSceneManager(ctrl);
          return Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_status,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      // Place
                      ElevatedButton.icon(
                          onPressed: () async {
                            final hits = await ctrl.hitTest(0.5, 0.6);
                            if (hits.isEmpty || !mounted) return;
                            final node = ARNode(
                              id: 'sphere_${DateTime.now().millisecondsSinceEpoch}',
                              primitiveShape: ARPrimitiveShape.sphere,
                              scale: const ARVector3(0.12, 0.12, 0.12),
                              material: const ARMaterial(
                                  baseColor:
                                      ARMaterialColor(r: 0.2, g: 0.6, b: 1)),
                            );
                            final entity = await _scene!
                                .placeEntity(node: node, at: hits.first);
                            setState(() {
                              _activeEntityId = entity.id;
                              _status = 'Sphere placed!';
                            });
                          },
                          icon: const Icon(Icons.circle),
                          label: const Text('Place Sphere')),
                      // Pulse
                      ElevatedButton.icon(
                          onPressed: () {
                            final id = _activeEntityId;
                            if (id == null) return;
                            _scene!.pulseColor(
                                id,
                                const ARMaterialColor(r: 1, g: 0.2, b: 0.2),
                                const ARMaterialColor(r: 0.2, g: 0.2, b: 1));
                            setState(() => _status = 'Pulsing red ↔ blue');
                          },
                          icon: const Icon(Icons.flare),
                          label: const Text('Pulse'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple)),
                      // Animate to green
                      ElevatedButton.icon(
                          onPressed: () {
                            final id = _activeEntityId;
                            if (id == null) return;
                            _scene!.animateColor(
                                id, const ARMaterialColor(r: 0.1, g: 1, b: 0.3),
                                duration: 0.8, curve: ARCurve.easeInOut);
                            setState(() => _status = 'Animating to green');
                          },
                          icon: const Icon(Icons.color_lens),
                          label: const Text('→ Green'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700])),
                      // Stop animations
                      ElevatedButton.icon(
                          onPressed: () {
                            if (_activeEntityId != null) {
                              _scene!.stopAnimations(_activeEntityId!);
                              setState(() => _status = 'Animations stopped');
                            }
                          },
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[700])),
                    ]),
              ]),
            ),
          );
        },
      );
}

// ─── Demo 6: Snapshot & Share ─────────────────────────────────────────────────

class SnapshotScreen extends StatefulWidget {
  const SnapshotScreen({super.key});
  @override
  State<SnapshotScreen> createState() => _SnapshotState();
}

class _SnapshotState extends State<SnapshotScreen> {
  ARSceneManager? _scene;
  ARScreenRecorder? _recorder;
  Uint8List? _snapshot;
  bool _recording = false;
  String _status = 'Tap Capture to take a snapshot';

  @override
  Widget build(BuildContext context) => _ARBase(
        title: 'Snapshot & Record',
        content: (ctrl, ctx) {
          _scene ??= ARSceneManager(ctrl);
          _recorder ??= ARScreenRecorder(controller: ctrl);

          return Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Preview thumbnail
                if (_snapshot != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 120,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                            image: MemoryImage(_snapshot!), fit: BoxFit.cover)),
                  ),
                Text(_status,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      // Capture
                      ElevatedButton.icon(
                          onPressed: () async {
                            setState(() => _status = 'Capturing…');
                            final bytes = await ctrl.captureSnapshot();
                            if (!mounted) return;
                            setState(() {
                              _snapshot = bytes;
                              _status = bytes != null
                                  ? 'Snapshot captured (${bytes.length} bytes)'
                                  : 'Snapshot failed (session not tracking?)';
                            });
                          },
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('Capture')),
                      // Record toggle
                      ElevatedButton.icon(
                          onPressed: () async {
                            if (_recording) {
                              final result = await _recorder!.stop();
                              setState(() {
                                _recording = false;
                                _status = result.succeeded
                                    ? 'Saved: ${result.frameCount} frames '
                                        '(${(result.fileSizeBytes / 1024).toStringAsFixed(0)} KB)'
                                    : 'Recording failed: ${result.errorMessage}';
                              });
                            } else {
                              await _recorder!.start();
                              setState(() {
                                _recording = true;
                                _status = 'Recording…';
                              });
                            }
                          },
                          icon: Icon(_recording
                              ? Icons.stop
                              : Icons.fiber_manual_record),
                          label: Text(_recording ? 'Stop' : 'Record'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _recording ? Colors.red : Colors.grey[700])),
                    ]),
              ]),
            ),
          );
        },
      );
}

// ─── Demo 7: Debug Overlay ────────────────────────────────────────────────────

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override
  State<DebugScreen> createState() => _DebugState();
}

class _DebugState extends State<DebugScreen> {
  bool _planes = true;
  bool _fps = true;
  bool _pose = true;
  bool _tracking = true;
  bool _entities = true;
  bool _light = true;
  bool _anchors = false;
  bool _bounds = false;

  @override
  Widget build(BuildContext context) => _ARBase(
        title: 'Debug Overlay',
        content: (ctrl, ctx) => Stack(children: [
          ARDebugOverlay(
            controller: ctrl,
            showPlanes: _planes,
            showFPS: _fps,
            showPose: _pose,
            showTrackingState: _tracking,
            showEntityCount: _entities,
            showLightEstimate: _light,
            showAnchorPositions: _anchors,
            showNodeBounds: _bounds,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Debug Layers',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 6),
                _sw('Plane Outlines', _planes,
                    (v) => setState(() => _planes = v)),
                _sw('FPS Counter', _fps, (v) => setState(() => _fps = v)),
                _sw('Camera Pose', _pose, (v) => setState(() => _pose = v)),
                _sw('Tracking State', _tracking,
                    (v) => setState(() => _tracking = v)),
                _sw('Entity Count', _entities,
                    (v) => setState(() => _entities = v)),
                _sw('Light Estimate', _light,
                    (v) => setState(() => _light = v)),
                _sw('Anchor Markers', _anchors,
                    (v) => setState(() => _anchors = v)),
                _sw('Node Bounds', _bounds, (v) => setState(() => _bounds = v)),
              ]),
            ),
          ),
        ]),
      );

  Widget _sw(String label, bool val, void Function(bool) cb) => Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13))),
        Switch.adaptive(
            value: val, onChanged: cb, activeColor: const Color(0xFF00E5FF)),
      ]);
}
