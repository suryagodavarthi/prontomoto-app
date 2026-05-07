import 'dart:typed_data';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

// ---------------------------------------------------------------------------
// Silhouette type mapping
// ---------------------------------------------------------------------------

enum _SilhouetteType {
  frontCorner,  // Front Left / Front Right Side  (3/4 front)
  frontView,    // Front View (grille)             (dead-on front)
  rearCorner,   // Rear Left / Rear Right Side     (3/4 rear)
  rearView,     // Rear View (tailgate)            (dead-on rear)
  sideProfile,  // Driver's / Passenger Side Profile
  interior,     // Dashboard, Gear & Seats
  detail,       // Chassis, Odometer, Engine Bay, Tires…
  selfie,       // Selfie with Vehicle
  underbody,    // Underbody
}

_SilhouetteType _silhouetteFor(String slotName) {
  const map = <String, _SilhouetteType>{
    "Front Left Side":       _SilhouetteType.frontCorner,
    "Front Right Side":      _SilhouetteType.frontCorner,
    "Rear Left Side":        _SilhouetteType.rearCorner,
    "Rear Right Side":       _SilhouetteType.rearCorner,
    "Front View (grille)":   _SilhouetteType.frontView,
    "Rear View (tailgate)":  _SilhouetteType.rearView,
    "Driver's Side Profile": _SilhouetteType.sideProfile,
    "Passenger Side Profile":_SilhouetteType.sideProfile,
    "Dashboard":             _SilhouetteType.interior,
    "Instrument Cluster":    _SilhouetteType.detail,
    "Engine Bay":            _SilhouetteType.detail,
    "Chassis Number Plate":  _SilhouetteType.detail,
    "Chassis Imprint":       _SilhouetteType.detail,
    "Gear and Seats":        _SilhouetteType.interior,
    "Dashboard Close-up":    _SilhouetteType.detail,
    "Odometer":              _SilhouetteType.detail,
    "Selfie with Vehicle":   _SilhouetteType.selfie,
    "Underbody":             _SilhouetteType.underbody,
    "Tires and Rims":        _SilhouetteType.detail,
    "Vehicle Video":         _SilhouetteType.sideProfile,
  };
  return map[slotName] ?? _SilhouetteType.frontView;
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class CustomCameraPage extends StatefulWidget {
  final String slotName;
  final bool isVideo;

  const CustomCameraPage({
    super.key,
    required this.slotName,
    this.isVideo = false,
  });

  @override
  State<CustomCameraPage> createState() => _CustomCameraPageState();
}

class _CustomCameraPageState extends State<CustomCameraPage>
    with WidgetsBindingObserver {
  CameraController? _ctrl;
  bool _ready = false;
  bool _capturing = false;
  bool _recording = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _ctrl?.dispose();
      _ctrl = null;
      if (mounted) setState(() => _ready = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    // ── 1. Request runtime camera permission ──────────────────────────────
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      if (mounted) {
        setState(() => _error =
            "Camera permission denied.\nPlease grant Camera access in Settings.");
      }
      return;
    }
    if (widget.isVideo) {
      await Permission.microphone.request(); // best-effort for video audio
    }

    // ── 2. Find back camera ───────────────────────────────────────────────
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _error = "No camera found on this device.");
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // ── 3. Initialise controller ────────────────────────────────────────
      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: widget.isVideo,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _ctrl = ctrl;
        _ready = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = "Camera error: $e");
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _capturePhoto() async {
    if (_ctrl == null || !_ready || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await _ctrl!.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) Navigator.pop(context, bytes);
    } catch (e) {
      if (mounted) {
        _showSnack("Capture failed: $e");
        setState(() => _capturing = false);
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_ctrl == null || !_ready) return;
    if (_recording) {
      setState(() => _recording = false);
      try {
        final file = await _ctrl!.stopVideoRecording();
        final bytes = await file.readAsBytes();
        if (mounted) Navigator.pop(context, bytes);
      } catch (e) {
        if (mounted) _showSnack("Recording error: $e");
      }
    } else {
      try {
        await _ctrl!.startVideoRecording();
        if (mounted) setState(() => _recording = true);
      } catch (e) {
        if (mounted) _showSnack("Could not start recording: $e");
      }
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _error != null
            ? _buildError()
            : !_ready
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : _buildLiveView(),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.camera_alt, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.5)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              child: const Text("Open Settings"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Go Back",
                  style: TextStyle(color: Colors.white70)),
            ),
          ]),
        ),
      );

  Widget _buildLiveView() {
    final silType = _silhouetteFor(widget.slotName);
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Live camera feed ─────────────────────────────────────────────
        CameraPreview(_ctrl!),

        // ── Vehicle silhouette overlay ───────────────────────────────────
        CustomPaint(painter: _VehicleSilhouettePainter(silType)),

        // ── Left label (slot name, rotated upward) ───────────────────────
        Positioned(
          left: 6,
          top: 0,
          bottom: 0,
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: Colors.yellow.withOpacity(0.88),
                child: Text(
                  "${widget.slotName}*",
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),

        // ── Right label (orientation, rotated downward) ──────────────────
        Positioned(
          right: 6,
          top: 0,
          bottom: 0,
          child: Center(
            child: RotatedBox(
              quarterTurns: 1,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                color: Colors.yellow.withOpacity(0.88),
                child: const Text(
                  "Capture in LANDSCAPE MODE only",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),

        // ── Top bar ──────────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(52, 8, 52, 8),
              child: Row(children: [
                Expanded(
                  child: Text(
                    widget.slotName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                    ),
                  ),
                ),
                if (_recording)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.fiber_manual_record,
                          color: Colors.white, size: 10),
                      SizedBox(width: 4),
                      Text("REC",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
              ]),
            ),
          ),
        ),

        // ── Back button ──────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 36,
          child: SafeArea(
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ),

        // ── Shutter / record button ───────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.black54,
              child: Center(
                child:
                    widget.isVideo ? _videoBtn() : _shutterBtn(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _shutterBtn() => GestureDetector(
        onTap: _capturing ? null : _capturePhoto,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            color: _capturing
                ? Colors.grey.withOpacity(0.5)
                : Colors.white.withOpacity(0.25),
          ),
          child: _capturing
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.camera_alt, color: Colors.white, size: 30),
        ),
      );

  Widget _videoBtn() => GestureDetector(
        onTap: _toggleRecording,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: _recording ? Colors.red : Colors.white, width: 4),
            color: _recording
                ? Colors.red.withOpacity(0.35)
                : Colors.white.withOpacity(0.25),
          ),
          child: Icon(
            _recording ? Icons.stop : Icons.videocam,
            color: _recording ? Colors.red : Colors.white,
            size: 30,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Silhouette Painter  — all shapes redesigned with proper car proportions
// ---------------------------------------------------------------------------

class _VehicleSilhouettePainter extends CustomPainter {
  final _SilhouetteType type;
  const _VehicleSilhouettePainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case _SilhouetteType.frontView:    _front(canvas, size, p);
      case _SilhouetteType.frontCorner:  _frontCorner(canvas, size, p);
      case _SilhouetteType.rearView:     _rear(canvas, size, p);
      case _SilhouetteType.rearCorner:   _rearCorner(canvas, size, p);
      case _SilhouetteType.sideProfile:  _side(canvas, size, p);
      case _SilhouetteType.interior:     _interior(canvas, size, p);
      case _SilhouetteType.detail:       _detail(canvas, size, p);
      case _SilhouetteType.selfie:       _selfie(canvas, size, p);
      case _SilhouetteType.underbody:    _underbody(canvas, size, p);
    }
  }

  // Shorthand helpers
  Offset _o(double x, double y, Size s) => Offset(x * s.width, y * s.height);
  Rect   _r(double l, double t, double w, double h, Size s) =>
      Rect.fromLTWH(l * s.width, t * s.height, w * s.width, h * s.height);

  // ─────────────────────────────────────────────────────────────────────────
  // FRONT VIEW  (dead-on, symmetric)
  // ─────────────────────────────────────────────────────────────────────────
  void _front(Canvas canvas, Size s, Paint p) {
    // Outer body + cabin in one sweep
    // Cabin narrows at the top, body is wide
    final outline = Path()
      ..moveTo(s.width * 0.30, s.height * 0.18)   // roof-left
      ..lineTo(s.width * 0.70, s.height * 0.18)   // roof-right
      ..lineTo(s.width * 0.82, s.height * 0.34)   // A-pillar right (shoulder)
      ..lineTo(s.width * 0.88, s.height * 0.38)   // fender right
      ..lineTo(s.width * 0.88, s.height * 0.72)   // body right side
      ..lineTo(s.width * 0.12, s.height * 0.72)   // bumper bottom
      ..lineTo(s.width * 0.12, s.height * 0.38)   // body left side
      ..lineTo(s.width * 0.18, s.height * 0.34)   // fender left
      ..close();
    canvas.drawPath(outline, p);

    // Windshield (inner trapezoid inside cabin)
    final wind = Path()
      ..moveTo(s.width * 0.34, s.height * 0.21)
      ..lineTo(s.width * 0.66, s.height * 0.21)
      ..lineTo(s.width * 0.76, s.height * 0.33)
      ..lineTo(s.width * 0.24, s.height * 0.33)
      ..close();
    canvas.drawPath(wind, p);

    // Hood line (horizontal, separates windshield base from grille)
    canvas.drawLine(_o(0.12, 0.38, s), _o(0.88, 0.38, s), p);

    // Left headlight – horizontal DRL strip
    final rrLeft = RRect.fromRectAndRadius(
        _r(0.13, 0.39, 0.20, 0.09, s), const Radius.circular(3));
    canvas.drawRRect(rrLeft, p);

    // Right headlight
    final rrRight = RRect.fromRectAndRadius(
        _r(0.67, 0.39, 0.20, 0.09, s), const Radius.circular(3));
    canvas.drawRRect(rrRight, p);

    // Grille opening (between headlights)
    final rrGrille = RRect.fromRectAndRadius(
        _r(0.34, 0.42, 0.32, 0.18, s), const Radius.circular(4));
    canvas.drawRRect(rrGrille, p);
    // Two horizontal bars inside grille
    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(
          _o(0.34, 0.42 + i * 0.06, s), _o(0.66, 0.42 + i * 0.06, s), p);
    }

    // Number plate
    canvas.drawRect(_r(0.36, 0.62, 0.28, 0.07, s), p);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FRONT CORNER  (3/4 front-left – you see the front + left side)
  // ─────────────────────────────────────────────────────────────────────────
  void _frontCorner(Canvas canvas, Size s, Paint p) {
    // Outer body in perspective
    final outline = Path()
      ..moveTo(s.width * 0.24, s.height * 0.16)   // roof left
      ..lineTo(s.width * 0.76, s.height * 0.19)   // roof right (recedes)
      ..lineTo(s.width * 0.88, s.height * 0.34)   // A-pillar right
      ..lineTo(s.width * 0.90, s.height * 0.38)
      ..lineTo(s.width * 0.90, s.height * 0.74)   // body right
      ..lineTo(s.width * 0.10, s.height * 0.74)   // bumper bottom
      ..lineTo(s.width * 0.10, s.height * 0.42)
      ..lineTo(s.width * 0.14, s.height * 0.36)   // A-pillar left
      ..close();
    canvas.drawPath(outline, p);

    // Windshield inner
    final wind = Path()
      ..moveTo(s.width * 0.28, s.height * 0.20)
      ..lineTo(s.width * 0.72, s.height * 0.23)
      ..lineTo(s.width * 0.82, s.height * 0.34)
      ..lineTo(s.width * 0.19, s.height * 0.34)
      ..close();
    canvas.drawPath(wind, p);

    // Hood line
    canvas.drawLine(_o(0.10, 0.42, s), _o(0.90, 0.42, s), p);

    // Front headlight (left, dominant – you're looking at the front-left)
    canvas.drawRRect(
        RRect.fromRectAndRadius(_r(0.11, 0.43, 0.25, 0.09, s),
            const Radius.circular(3)),
        p);

    // Right headlight (smaller, perspective foreshortened)
    canvas.drawRRect(
        RRect.fromRectAndRadius(_r(0.68, 0.44, 0.18, 0.08, s),
            const Radius.circular(3)),
        p);

    // Grille (between headlights, slightly off-centre due to perspective)
    canvas.drawRRect(
        RRect.fromRectAndRadius(_r(0.37, 0.47, 0.28, 0.16, s),
            const Radius.circular(4)),
        p);
    canvas.drawLine(_o(0.37, 0.53, s), _o(0.65, 0.53, s), p);
    canvas.drawLine(_o(0.37, 0.58, s), _o(0.65, 0.58, s), p);

    // Number plate
    canvas.drawRect(_r(0.36, 0.65, 0.26, 0.07, s), p);

    // Left-side fender visible (thin vertical strip on left edge)
    canvas.drawLine(_o(0.10, 0.42, s), _o(0.10, 0.74, s), p);

    // Left front wheel arch (partially visible at bottom left)
    canvas.drawArc(
      Rect.fromCenter(
          center: _o(0.22, 0.74, s),
          width: s.width * 0.22,
          height: s.height * 0.18),
      math.pi, math.pi, false, p,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REAR VIEW  (dead-on, symmetric)
  // ─────────────────────────────────────────────────────────────────────────
  void _rear(Canvas canvas, Size s, Paint p) {
    // Outer body + cabin
    final outline = Path()
      ..moveTo(s.width * 0.30, s.height * 0.18)
      ..lineTo(s.width * 0.70, s.height * 0.18)
      ..lineTo(s.width * 0.82, s.height * 0.34)
      ..lineTo(s.width * 0.88, s.height * 0.38)
      ..lineTo(s.width * 0.88, s.height * 0.74)
      ..lineTo(s.width * 0.12, s.height * 0.74)
      ..lineTo(s.width * 0.12, s.height * 0.38)
      ..lineTo(s.width * 0.18, s.height * 0.34)
      ..close();
    canvas.drawPath(outline, p);

    // Rear window
    final wind = Path()
      ..moveTo(s.width * 0.34, s.height * 0.21)
      ..lineTo(s.width * 0.66, s.height * 0.21)
      ..lineTo(s.width * 0.76, s.height * 0.33)
      ..lineTo(s.width * 0.24, s.height * 0.33)
      ..close();
    canvas.drawPath(wind, p);

    // Boot lid line
    canvas.drawLine(_o(0.18, 0.38, s), _o(0.82, 0.38, s), p);

    // Left tail light (L-shape: wide horizontal + small vertical)
    canvas.drawPath(
      Path()
        ..moveTo(s.width * 0.12, s.height * 0.38)
        ..lineTo(s.width * 0.12, s.height * 0.54)
        ..lineTo(s.width * 0.30, s.height * 0.52)
        ..lineTo(s.width * 0.30, s.height * 0.38),
      p,
    );

    // Right tail light (mirror)
    canvas.drawPath(
      Path()
        ..moveTo(s.width * 0.88, s.height * 0.38)
        ..lineTo(s.width * 0.88, s.height * 0.54)
        ..lineTo(s.width * 0.70, s.height * 0.52)
        ..lineTo(s.width * 0.70, s.height * 0.38),
      p,
    );

    // Rear bumper body line
    canvas.drawLine(_o(0.12, 0.62, s), _o(0.88, 0.62, s), p);

    // Number plate
    canvas.drawRect(_r(0.34, 0.54, 0.32, 0.08, s), p);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REAR CORNER  (3/4 rear-left)
  // ─────────────────────────────────────────────────────────────────────────
  void _rearCorner(Canvas canvas, Size s, Paint p) {
    final outline = Path()
      ..moveTo(s.width * 0.22, s.height * 0.16)
      ..lineTo(s.width * 0.77, s.height * 0.19)
      ..lineTo(s.width * 0.87, s.height * 0.34)
      ..lineTo(s.width * 0.90, s.height * 0.38)
      ..lineTo(s.width * 0.90, s.height * 0.74)
      ..lineTo(s.width * 0.10, s.height * 0.74)
      ..lineTo(s.width * 0.10, s.height * 0.42)
      ..lineTo(s.width * 0.13, s.height * 0.36)
      ..close();
    canvas.drawPath(outline, p);

    // Rear window
    final wind = Path()
      ..moveTo(s.width * 0.27, s.height * 0.20)
      ..lineTo(s.width * 0.73, s.height * 0.23)
      ..lineTo(s.width * 0.82, s.height * 0.34)
      ..lineTo(s.width * 0.18, s.height * 0.34)
      ..close();
    canvas.drawPath(wind, p);

    // Boot lid line
    canvas.drawLine(_o(0.13, 0.42, s), _o(0.90, 0.42, s), p);

    // Left tail light (this side dominates in 3/4-left view)
    canvas.drawPath(
      Path()
        ..moveTo(s.width * 0.10, s.height * 0.42)
        ..lineTo(s.width * 0.10, s.height * 0.58)
        ..lineTo(s.width * 0.26, s.height * 0.56)
        ..lineTo(s.width * 0.26, s.height * 0.42),
      p,
    );

    // Right tail light (smaller, foreshortened)
    canvas.drawPath(
      Path()
        ..moveTo(s.width * 0.76, s.height * 0.44)
        ..lineTo(s.width * 0.76, s.height * 0.54)
        ..lineTo(s.width * 0.90, s.height * 0.52)
        ..lineTo(s.width * 0.90, s.height * 0.44),
      p,
    );

    // Bumper line
    canvas.drawLine(_o(0.10, 0.62, s), _o(0.90, 0.62, s), p);

    // Number plate
    canvas.drawRect(_r(0.35, 0.53, 0.28, 0.08, s), p);

    // Left wheel arch
    canvas.drawArc(
      Rect.fromCenter(
          center: _o(0.24, 0.74, s),
          width: s.width * 0.26,
          height: s.height * 0.18),
      math.pi, math.pi, false, p,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SIDE PROFILE  (classic silhouette from the side)
  // ─────────────────────────────────────────────────────────────────────────
  void _side(Canvas canvas, Size s, Paint p) {
    // Body outline — sedan shape
    final body = Path()
      // Start: front bumper bottom
      ..moveTo(s.width * 0.07, s.height * 0.70)
      // Front bumper face
      ..lineTo(s.width * 0.06, s.height * 0.56)
      // Hood slopes upward toward cabin
      ..lineTo(s.width * 0.10, s.height * 0.42)
      ..lineTo(s.width * 0.18, s.height * 0.32)
      // A-pillar up to roof
      ..lineTo(s.width * 0.26, s.height * 0.22)
      // Roof across
      ..lineTo(s.width * 0.68, s.height * 0.20)
      // C-pillar slopes down (typical sedan)
      ..lineTo(s.width * 0.76, s.height * 0.26)
      ..lineTo(s.width * 0.82, s.height * 0.36)
      // Boot lid
      ..lineTo(s.width * 0.91, s.height * 0.38)
      // Rear bumper
      ..lineTo(s.width * 0.94, s.height * 0.48)
      ..lineTo(s.width * 0.94, s.height * 0.62)
      ..lineTo(s.width * 0.92, s.height * 0.70)
      ..close();
    canvas.drawPath(body, p);

    // Door divider (A-B pillar gap)
    canvas.drawLine(_o(0.44, 0.28, s), _o(0.44, 0.60, s), p);

    // Front window
    final fWin = Path()
      ..moveTo(s.width * 0.28, s.height * 0.26)
      ..lineTo(s.width * 0.43, s.height * 0.24)
      ..lineTo(s.width * 0.43, s.height * 0.46)
      ..lineTo(s.width * 0.28, s.height * 0.48)
      ..close();
    canvas.drawPath(fWin, p);

    // Rear window
    final rWin = Path()
      ..moveTo(s.width * 0.46, s.height * 0.24)
      ..lineTo(s.width * 0.66, s.height * 0.23)
      ..lineTo(s.width * 0.72, s.height * 0.28)
      ..lineTo(s.width * 0.66, s.height * 0.44)
      ..lineTo(s.width * 0.46, s.height * 0.46)
      ..close();
    canvas.drawPath(rWin, p);

    // Waist line (character line)
    canvas.drawLine(_o(0.10, 0.52, s), _o(0.91, s.height * 0.52 / s.height, s), p);

    // Front wheel (circle)
    canvas.drawCircle(_o(0.24, 0.70, s), s.width * 0.12, p);
    canvas.drawCircle(_o(0.24, 0.70, s), s.width * 0.06, p); // hub

    // Rear wheel (circle)
    canvas.drawCircle(_o(0.74, 0.70, s), s.width * 0.12, p);
    canvas.drawCircle(_o(0.74, 0.70, s), s.width * 0.06, p); // hub

    // Headlight
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            _r(0.06, 0.44, 0.07, 0.10, s), const Radius.circular(2)),
        p);

    // Tail light
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            _r(0.88, 0.40, 0.06, 0.12, s), const Radius.circular(2)),
        p);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INTERIOR  (steering wheel + dashboard)
  // ─────────────────────────────────────────────────────────────────────────
  void _interior(Canvas canvas, Size s, Paint p) {
    final cx = s.width * 0.40;
    final cy = s.height * 0.52;
    final r1 = s.width * 0.15; // rim radius
    final r2 = s.width * 0.05; // hub radius

    // Steering wheel rim
    canvas.drawCircle(Offset(cx, cy), r1, p);
    // Hub
    canvas.drawCircle(Offset(cx, cy), r2, p);
    // 3 spokes
    for (int i = 0; i < 3; i++) {
      final angle = math.pi / 2 + i * (2 * math.pi / 3);
      canvas.drawLine(
        Offset(cx + r2 * math.cos(angle), cy + r2 * math.sin(angle)),
        Offset(cx + r1 * math.cos(angle), cy + r1 * math.sin(angle)),
        p,
      );
    }
    // Column
    canvas.drawLine(
        Offset(cx, cy + r1),
        Offset(cx, s.height * 0.74),
        p);

    // Dashboard bar
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            _r(0.10, 0.68, 0.80, 0.06, s), const Radius.circular(6)),
        p);

    // 3 AC vents on dashboard
    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              _r(0.20 + i * 0.20, 0.22, 0.12, 0.07, s),
              const Radius.circular(3)),
          p);
    }

    // Instrument cluster (right side oval)
    canvas.drawOval(_r(0.60, 0.30, 0.26, 0.20, s), p);
    // Speedometer arc
    canvas.drawArc(_r(0.64, 0.34, 0.18, 0.12, s),
        math.pi * 0.8, math.pi * 1.4, false, p);

    // Centre console
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            _r(0.46, 0.74, 0.16, 0.14, s), const Radius.circular(4)),
        p);
    canvas.drawCircle(_o(0.54, 0.79, s), s.width * 0.025, p); // gear knob
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DETAIL  (close-up bracket frame with crosshair)
  // ─────────────────────────────────────────────────────────────────────────
  void _detail(Canvas canvas, Size s, Paint p) {
    const arm = 0.10; // bracket arm length (fraction of screen)
    // Four corner brackets
    final corners = <List<double>>[
      [0.18, 0.25,  arm, 0.0,  arm, 0.0],  // top-left
      [0.82, 0.25, -arm, 0.0,  arm, 0.0],  // top-right
      [0.18, 0.75,  arm, 0.0, -arm, 0.0],  // bottom-left
      [0.82, 0.75, -arm, 0.0, -arm, 0.0],  // bottom-right
    ];
    for (final c in corners) {
      final cx = c[0] * s.width;
      final cy = c[1] * s.height;
      canvas.drawLine(Offset(cx, cy),
          Offset(cx + c[2] * s.width, cy), p);
      canvas.drawLine(Offset(cx, cy),
          Offset(cx, cy + c[4] * s.height), p);
    }
    // Faint crosshair
    final faint = Paint()
      ..color = Colors.white.withOpacity(0.28)
      ..strokeWidth = 1.0;
    canvas.drawLine(_o(0.18, 0.50, s), _o(0.42, 0.50, s), faint);
    canvas.drawLine(_o(0.58, 0.50, s), _o(0.82, 0.50, s), faint);
    canvas.drawLine(_o(0.50, 0.25, s), _o(0.50, 0.42, s), faint);
    canvas.drawLine(_o(0.50, 0.58, s), _o(0.50, 0.75, s), faint);
    // Centre dot
    canvas.drawCircle(_o(0.50, 0.50, s), 4, faint);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SELFIE  (person + car, both in frame)
  // ─────────────────────────────────────────────────────────────────────────
  void _selfie(Canvas canvas, Size s, Paint p) {
    // Car on the left (simpler side silhouette, scaled down)
    final car = Path()
      ..moveTo(s.width * 0.05, s.height * 0.65)
      ..lineTo(s.width * 0.05, s.height * 0.52)
      ..lineTo(s.width * 0.09, s.height * 0.42)
      ..lineTo(s.width * 0.15, s.height * 0.35)
      ..lineTo(s.width * 0.22, s.height * 0.29)
      ..lineTo(s.width * 0.46, s.height * 0.28)
      ..lineTo(s.width * 0.52, s.height * 0.34)
      ..lineTo(s.width * 0.56, s.height * 0.44)
      ..lineTo(s.width * 0.58, s.height * 0.65)
      ..close();
    canvas.drawPath(car, p);
    // Front wheel
    canvas.drawCircle(_o(0.17, 0.65, s), s.width * 0.08, p);
    // Rear wheel
    canvas.drawCircle(_o(0.46, 0.65, s), s.width * 0.08, p);
    // Number plate on car
    canvas.drawRect(_r(0.12, 0.59, 0.14, 0.04, s), p);

    // Person on the right (stick figure)
    canvas.drawCircle(_o(0.76, 0.26, s), s.width * 0.07, p); // head
    canvas.drawLine(_o(0.76, 0.34, s), _o(0.76, 0.56, s), p); // torso
    canvas.drawLine(_o(0.76, 0.38, s), _o(0.66, 0.50, s), p); // left arm
    canvas.drawLine(_o(0.76, 0.38, s), _o(0.86, 0.50, s), p); // right arm
    canvas.drawLine(_o(0.76, 0.56, s), _o(0.70, 0.74, s), p); // left leg
    canvas.drawLine(_o(0.76, 0.56, s), _o(0.82, 0.74, s), p); // right leg

    // Yellow "both must be in frame" border
    canvas.drawRect(
      _r(0.04, 0.14, 0.92, 0.66, s),
      Paint()
        ..color = Colors.yellow.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UNDERBODY  (view from below looking up)
  // ─────────────────────────────────────────────────────────────────────────
  void _underbody(Canvas canvas, Size s, Paint p) {
    // Outer floor pan rectangle
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            _r(0.10, 0.22, 0.80, 0.56, s), const Radius.circular(6)),
        p);

    // Two longitudinal chassis rails
    canvas.drawRect(_r(0.22, 0.25, 0.10, 0.50, s), p);
    canvas.drawRect(_r(0.68, 0.25, 0.10, 0.50, s), p);

    // 4 cross-members
    for (int i = 0; i < 4; i++) {
      final y = 0.28 + i * 0.13;
      canvas.drawLine(_o(0.22, y, s), _o(0.78, y, s), p);
    }

    // Exhaust pipe (centre, runs front to back)
    canvas.drawPath(
      Path()
        ..moveTo(s.width * 0.50, s.height * 0.25)
        ..lineTo(s.width * 0.50, s.height * 0.68)
        ..lineTo(s.width * 0.54, s.height * 0.72),
      p,
    );

    // Fuel tank oval
    canvas.drawOval(_r(0.36, 0.38, 0.28, 0.10, s), p);

    // "POINT CAMERA DOWN" hint
    _label(canvas, s, 'POINT CAMERA DOWNWARD', 0.50, 0.16,
        Colors.white.withOpacity(0.55));
  }

  void _label(Canvas canvas, Size s, String text, double cx, double cy,
      Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset(cx * s.width - tp.width / 2, cy * s.height));
  }

  @override
  bool shouldRepaint(covariant _VehicleSilhouettePainter old) =>
      old.type != type;
}
