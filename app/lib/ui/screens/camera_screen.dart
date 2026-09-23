import 'dart:async';

import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/image_ops.dart';

/// DARM Camera — a purpose-built, in-app capture screen for skin lesions.
///
/// Unlike `image_picker`'s camera (which launches the OS camera app), this gives
/// us a live preview, a lesion-alignment guide, torch control, tap-to-focus and
/// pinch-zoom, and captures at high resolution for medical-grade framing.
///
/// Pushed as a route; pops with the captured `Uint8List` (JPEG bytes), or `null`
/// if the user backs out.
class DarmCameraScreen extends StatefulWidget {
  const DarmCameraScreen({super.key});

  @override
  State<DarmCameraScreen> createState() => _DarmCameraScreenState();
}

class _DarmCameraScreenState extends State<DarmCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  bool _initializing = true;
  bool _capturing = false;
  String? _error;

  // Multi-shot: capture a small burst and auto-keep the sharpest frame.
  final ImageOps _ops = ImageOps();
  static const int _burstN = 3;
  bool _burst = true;
  String? _status; // progress text shown during a burst

  FlashMode _flash = FlashMode.off;

  // Zoom bounds + current level.
  double _minZoom = 1, _maxZoom = 1, _zoom = 1;
  double _baseZoom = 1; // zoom at the start of a pinch gesture

  // Brief tap-to-focus indicator.
  Offset? _focusPoint;
  Timer? _focusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _initializing = false;
          _error = 'camera.noCamera'.tr();
        });
        return;
      }
      // Prefer the rear camera.
      _cameraIndex = _cameras
          .indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _startController(_cameras[_cameraIndex]);
    } catch (e) {
      setState(() {
        _initializing = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _startController(CameraDescription cam) async {
    final prev = _controller;
    final controller = CameraController(
      cam,
      // 720p: crisp for dermoscopic framing yet light on memory, so burst
      // capture stays smooth and stable on mid-range phones (model uses 448px).
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setFlashMode(_flash);
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _zoom = _minZoom.clamp(1, _maxZoom);
      await prev?.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (e is CameraException &&
        (e.code == 'CameraAccessDenied' ||
            e.code == 'CameraAccessDeniedWithoutPrompt' ||
            e.code.toLowerCase().contains('permission'))) {
      return 'camera.permissionNeeded'.tr();
    }
    return '${'camera.couldNotOpen'.tr()}\n$s';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startController(_cameras[_cameraIndex]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _cycleFlash() async {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.torch];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    setState(() => _flash = next);
    try {
      await _controller?.setFlashMode(next);
    } catch (_) {/* some devices don't support a mode; ignore */}
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    setState(() => _initializing = true);
    await _startController(_cameras[_cameraIndex]);
    if (mounted) setState(() => _initializing = false);
  }

  Future<void> _onTapFocus(TapDownDetails d, BoxConstraints c) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final x = (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0);
    final y = (d.localPosition.dy / c.maxHeight).clamp(0.0, 1.0);
    setState(() => _focusPoint = d.localPosition);
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 900),
        () => mounted ? setState(() => _focusPoint = null) : null);
    try {
      await controller.setFocusPoint(Offset(x, y));
      await controller.setExposurePoint(Offset(x, y));
    } catch (_) {/* not all devices support point focus */}
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails d) async {
    if (d.scale == 1.0) return;
    final z = (_baseZoom * d.scale).clamp(_minZoom, _maxZoom);
    if (z == _zoom) return;
    _zoom = z;
    try {
      await _controller?.setZoomLevel(z);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      if (!_burst) {
        final file = await controller.takePicture();
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        Navigator.of(context).pop(bytes);
        return;
      }

      // Burst: take N frames, then keep the sharpest automatically.
      final shots = <Uint8List>[];
      for (var i = 0; i < _burstN; i++) {
        if (!mounted) return;
        setState(() =>
            _status = 'camera.capturing'.tr(args: ['${i + 1}', '$_burstN']));
        final file = await controller.takePicture();
        shots.add(await file.readAsBytes());
        if (i < _burstN - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
      if (!mounted) return;
      setState(() => _status = 'camera.choosingSharpest'.tr());
      final best = await _ops.pickSharpest(shots);
      if (!mounted) return;
      Navigator.of(context).pop(best.bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _status = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('camera.captureFailed'.tr(args: ['$e']))),
      );
    }
  }

  IconData get _flashIcon => switch (_flash) {
        FlashMode.off => Icons.flash_off,
        FlashMode.auto => Icons.flash_auto,
        FlashMode.torch => Icons.flashlight_on,
        _ => Icons.flash_off,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _error != null
            ? _ErrorPane(
                message: _error!,
                onRetry: () {
                  setState(() {
                    _initializing = true;
                    _error = null;
                  });
                  _bootstrap();
                })
            : (_initializing ||
                    _controller == null ||
                    !_controller!.value.isInitialized)
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : _cameraUi(context),
      ),
    );
  }

  Widget _cameraUi(BuildContext context) {
    final controller = _controller!;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Live preview, sized to fill while preserving aspect ratio.
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTapDown: (d) => _onTapFocus(d, constraints),
              onScaleStart: (_) => _baseZoom = _zoom,
              onScaleUpdate: _onScaleUpdate,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.previewSize?.height ??
                          constraints.maxWidth,
                      height: controller.value.previewSize?.width ??
                          constraints.maxHeight,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Lesion-alignment guide.
        IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter:
                _GuidePainter(color: Theme.of(context).colorScheme.primary),
          ),
        ),

        // Tap-to-focus reticle.
        if (_focusPoint != null)
          Positioned(
            left: _focusPoint!.dx - 24,
            top: _focusPoint!.dy - 24,
            child: IgnorePointer(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ),

        // Top bar: close, guidance, flash.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _TopBar(
            flashIcon: _flashIcon,
            onClose: () => Navigator.of(context).pop(),
            onFlash: _cycleFlash,
          ),
        ),

        // Guidance chip.
        const Positioned(
          left: 0,
          right: 0,
          bottom: 150,
          child: Center(child: _GuidanceChip()),
        ),

        // Zoom readout.
        if (_maxZoom > 1.05)
          Positioned(
            right: 16,
            bottom: 150,
            child: _Pill(text: '${_zoom.toStringAsFixed(1)}x'),
          ),

        // Mode toggle: single vs auto "best of 3".
        Positioned(
          left: 0,
          right: 0,
          bottom: 116,
          child: Center(
            child: _ModeToggle(
              burst: _burst,
              onChanged: _capturing ? null : (v) => setState(() => _burst = v),
            ),
          ),
        ),

        // Bottom controls: switch, shutter.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomBar(
            capturing: _capturing,
            burst: _burst,
            canSwitch: _cameras.length > 1,
            onSwitch: _switchCamera,
            onCapture: _capture,
          ),
        ),

        // Burst progress overlay.
        if (_status != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(_status!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.burst, required this.onChanged});
  final bool burst;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget seg(String label, bool value) {
      final selected = burst == value;
      return GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
              )),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('camera.single'.tr(), false),
          seg('camera.bestOf3'.tr(), true)
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
class _GuidePainter extends CustomPainter {
  _GuidePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Centered square guide, ~74% of the shorter edge.
    final side = size.shortestSide * 0.74;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 20),
      width: side,
      height: side,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    // Dim everything outside the guide.
    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
        scrim, Paint()..color = Colors.black.withValues(alpha: 0.45));

    // Corner brackets.
    final p = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const c = 26.0;
    void corner(Offset o, Offset hx, Offset vy) {
      canvas.drawLine(o, o + hx, p);
      canvas.drawLine(o, o + vy, p);
    }

    corner(rect.topLeft, const Offset(c, 0), const Offset(0, c));
    corner(rect.topRight, const Offset(-c, 0), const Offset(0, c));
    corner(rect.bottomLeft, const Offset(c, 0), const Offset(0, -c));
    corner(rect.bottomRight, const Offset(-c, 0), const Offset(0, -c));

    // Center crosshair.
    final ctr = rect.center;
    final cross = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    canvas.drawLine(
        ctr + const Offset(-12, 0), ctr + const Offset(12, 0), cross);
    canvas.drawLine(
        ctr + const Offset(0, -12), ctr + const Offset(0, 12), cross);
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) => old.color != color;
}

// --------------------------------------------------------------------------- //
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.flashIcon,
    required this.onClose,
    required this.onFlash,
  });
  final IconData flashIcon;
  final VoidCallback onClose;
  final VoidCallback onFlash;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleIcon(icon: Icons.close, onTap: onClose),
          Text('camera.title'.tr(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
          _CircleIcon(icon: flashIcon, onTap: onFlash),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.capturing,
    required this.burst,
    required this.canSwitch,
    required this.onSwitch,
    required this.onCapture,
  });
  final bool capturing;
  final bool burst;
  final bool canSwitch;
  final VoidCallback onSwitch;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 28, top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: 56,
            child: canSwitch
                ? _CircleIcon(icon: Icons.cameraswitch, onTap: onSwitch)
                : null,
          ),
          // Shutter.
          GestureDetector(
            onTap: capturing ? null : onCapture,
            child: Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: capturing
                    ? const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: Colors.white),
                      )
                    : Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.white),
                        child: burst
                            ? const Text('3',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22))
                            : null,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }
}

class _GuidanceChip extends StatelessWidget {
  const _GuidanceChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'camera.guidance'.tr(),
        style: const TextStyle(color: Colors.white, fontSize: 12.5),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child:
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined,
              color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, height: 1.4)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
