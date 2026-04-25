import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/router/app_router.dart';
import '../../core/services/compass_service.dart';
import '../../core/services/location_service.dart';
import '../../shared/widgets/compass_overlay.dart';
import '../identification/identification_args.dart';

/// Camera screen — flash, flip lens, gallery import, compass overlay.
/// Hands the photo to the identify screen.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _flashOn = false;
  bool _taking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'No camera available. Try the gallery button.');
        return;
      }
      await _bindController(_cameras[_cameraIndex]);
    } on CameraException catch (e) {
      setState(() => _error = e.description ?? e.code);
    }
  }

  Future<void> _bindController(CameraDescription desc) async {
    final controller = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    _initFuture = controller.initialize();
    await _initFuture;
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed && _cameras.isNotEmpty) {
      _bindController(_cameras[_cameraIndex]);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null) return;
    final next = !_flashOn;
    await c.setFlashMode(next ? FlashMode.torch : FlashMode.off);
    setState(() => _flashOn = next);
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _controller?.dispose();
    await _bindController(_cameras[_cameraIndex]);
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
    );
    if (x == null) return;
    await _handleCaptured(x.path);
  }

  Future<void> _shoot() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _taking) return;
    setState(() => _taking = true);
    try {
      final file = await c.takePicture();
      await _handleCaptured(file.path);
    } on CameraException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: ${e.code}')),
      );
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  Future<void> _handleCaptured(String path) async {
    final heading = ref.read(compassHeadingProvider).value;
    final fix = await ref.read(locationServiceProvider).currentFix();
    if (!mounted) return;
    await context.push(
      AppRoutes.identify,
      extra: IdentificationArgs(
        imagePath: path,
        capturedAt: DateTime.now(),
        fix: fix,
        heading: heading,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heading = ref.watch(compassHeadingProvider).valueOrNull;
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Identify a plant',
            style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_error != null)
            _ErrorView(message: _error!, onGallery: _pickFromGallery)
          else if (controller == null || _initFuture == null)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            FutureBuilder<void>(
              future: _initFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                return _CameraPreviewArea(controller: controller);
              },
            ),
          CompassOverlay(heading: heading),
          _BottomControls(
            taking: _taking,
            flashOn: _flashOn,
            onShoot: _shoot,
            onFlip: _flipCamera,
            onFlash: _toggleFlash,
            onGallery: _pickFromGallery,
          ),
        ],
      ),
    );
  }
}

class _CameraPreviewArea extends StatelessWidget {
  const _CameraPreviewArea({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isPortrait = size.height >= size.width;
    final previewRatio = isPortrait
        ? 1 / controller.value.aspectRatio
        : controller.value.aspectRatio;
    final screenRatio = size.width / size.height;

    final double coverW;
    final double coverH;
    if (screenRatio < previewRatio) {
      coverH = size.height;
      coverW = coverH * previewRatio;
    } else {
      coverW = size.width;
      coverH = coverW / previewRatio;
    }

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: SizedBox(
          width: coverW,
          height: coverH,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.taking,
    required this.flashOn,
    required this.onShoot,
    required this.onFlip,
    required this.onFlash,
    required this.onGallery,
  });

  final bool taking;
  final bool flashOn;
  final Future<void> Function() onShoot;
  final Future<void> Function() onFlip;
  final Future<void> Function() onFlash;
  final Future<void> Function() onGallery;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.paddingOf(context).bottom + 24,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.65),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _RoundButton(
              icon: Icons.photo_library_outlined,
              onTap: onGallery,
            ),
            _ShutterButton(busy: taking, onTap: onShoot),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoundButton(
                  icon: flashOn ? Icons.flash_on : Icons.flash_off,
                  onTap: onFlash,
                ),
                const SizedBox(height: 12),
                _RoundButton(
                  icon: Icons.flip_camera_ios_outlined,
                  onTap: onFlip,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onTap});
  final bool busy;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 84,
        width: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: busy ? 28 : 60,
            width: busy ? 28 : 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: busy ? scheme.secondary : Colors.white,
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onGallery});
  final String message;
  final Future<void> Function() onGallery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, color: Colors.white.withValues(alpha: 0.7), size: 64),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Pick from gallery'),
          ),
        ],
      ),
    );
  }
}
