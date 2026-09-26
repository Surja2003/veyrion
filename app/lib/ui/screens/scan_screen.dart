import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../state/scan_controller.dart';
import '../widgets/common.dart';
import 'camera_screen.dart';
import 'crop_screen.dart';
import 'metadata_screen.dart';
import 'result_screen.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanController>();

    // When analysis completes, push the result screen once.
    if (scan.stage == ScanStage.result && scan.result != null) {
      final controller = scan;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.stage == ScanStage.result && context.mounted) {
          controller.stage = ScanStage.metadata; // consume flag
          Navigator.of(context)
              .push(MaterialPageRoute(
                // The result route is a child of the root Navigator, which sits
                // ABOVE HomeShell's ScanController provider — so re-expose the
                // same controller instance to the pushed subtree via .value.
                builder: (_) => ChangeNotifierProvider<ScanController>.value(
                  value: controller,
                  child: const ResultScreen(),
                ),
              ))
              .then((_) => controller.reset());
        }
      });
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _body(context, scan),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ScanController scan) {
    switch (scan.stage) {
      case ScanStage.capture:
        return const _CaptureView();
      case ScanStage.adjust:
        return const _AdjustView();
      case ScanStage.metadata:
        return const MetadataView();
      case ScanStage.analysing:
        return const _AnalysingView();
      case ScanStage.error:
        return _ErrorView(message: scan.error ?? 'Something went wrong');
      case ScanStage.result:
        return const _AnalysingView();
    }
  }
}

// --------------------------------------------------------------------------- //
class _CaptureView extends StatelessWidget {
  const _CaptureView();

  /// Use the in-app DARM camera on native mobile; elsewhere (web/desktop) fall
  /// back to the platform picker.
  static bool get _useDarmCam =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pick(BuildContext context, bool camera) async {
    final scan = context.read<ScanController>();
    try {
      Uint8List? bytes;
      if (camera) {
        // DARM camera already auto-picks the sharpest of its burst.
        bytes = _useDarmCam
            ? await Navigator.of(context).push<Uint8List>(
                MaterialPageRoute(
                  builder: (_) => const DarmCameraScreen(),
                  fullscreenDialog: true,
                ),
              )
            : await scan.ops.captureFromCamera();
      } else {
        // Gallery: let the user pick 2–3, keep the sharpest automatically.
        final shots = await scan.ops.pickMultipleFromGallery(limit: 3);
        if (shots.isEmpty) return;
        if (shots.length == 1) {
          bytes = shots.first;
        } else {
          final best = await scan.ops.pickSharpest(shots);
          bytes = best.bytes;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('scan.keptSharpest'.tr(args: ['${shots.length}'])),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
      if (bytes != null) scan.setImage(bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('scan.couldNotLoad'.tr(args: ['$e']))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.read<ScanController>();
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        Text('scan.title'.tr(),
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          'scan.intro'.tr(),
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        if (scan.ops.cameraSupported)
          FilledButton.icon(
            onPressed: () => _pick(context, true),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_useDarmCam
                ? 'scan.openCamera'.tr()
                : 'scan.openCameraPlain'.tr()),
          ),
        if (scan.ops.cameraSupported) const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _pick(context, false),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(scan.ops.cameraSupported
              ? 'scan.chooseGallery'.tr()
              : 'scan.chooseFiles'.tr()),
        ),
        const SizedBox(height: 24),
        const _TipsCard(),
        const SizedBox(height: 16),
        const DisclaimerBanner(),
      ],
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();
  @override
  Widget build(BuildContext context) {
    final tips = [
      'scan.tip1'.tr(),
      'scan.tip2'.tr(),
      'scan.tip3'.tr(),
      'scan.tip4'.tr(),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('scan.tipsTitle'.tr()),
            ...tips.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
class _AdjustView extends StatelessWidget {
  const _AdjustView();

  Future<void> _crop(BuildContext context) async {
    final scan = context.read<ScanController>();
    if (scan.originalBytes == null) return;
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(builder: (_) => CropScreen(image: scan.originalBytes!)),
    );
    if (result != null) scan.setCropped(result);
  }

  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanController>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SectionHeader('scan.fineTune'.tr()),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (scan.workingImage != null)
                  Image.memory(scan.workingImage!,
                      fit: BoxFit.contain, gaplessPlayback: true),
                if (scan.enhancing)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _crop(context),
                icon: const Icon(Icons.crop),
                label: Text('scan.crop'.tr()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.read<ScanController>().reset(),
                icon: const Icon(Icons.refresh),
                label: Text('scan.retake'.tr()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _EnhanceSliders(scan: scan),
        const SizedBox(height: 8),
        Text(
          'scan.enhanceNote'.tr(),
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => context.read<ScanController>().goToMetadata(),
          icon: const Icon(Icons.arrow_forward),
          label: Text('common.continue'.tr()),
        ),
      ],
    );
  }
}

class _EnhanceSliders extends StatelessWidget {
  const _EnhanceSliders({required this.scan});
  final ScanController scan;

  @override
  Widget build(BuildContext context) {
    Widget slider(String label, double value, double min, double max,
        ValueChanged<double> onChanged) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              Text(value.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: (_) => scan.applyEnhancements(),
          ),
        ],
      );
    }

    return Column(
      children: [
        slider('scan.brightness'.tr(), scan.brightness, -60, 60,
            (v) => scan.brightness = v),
        slider('scan.contrast'.tr(), scan.contrast, -60, 60,
            (v) => scan.contrast = v),
        slider('scan.saturation'.tr(), scan.saturation, -60, 60,
            (v) => scan.saturation = v),
        slider(
            'scan.sharpen'.tr(), scan.sharpen, 0, 100, (v) => scan.sharpen = v),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('scan.autoWhiteBalance'.tr()),
          value: scan.autoWhiteBalance,
          onChanged: (v) {
            scan.autoWhiteBalance = v;
            scan.applyEnhancements();
          },
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //
class _AnalysingView extends StatelessWidget {
  const _AnalysingView();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text('scan.analysing'.tr(),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(AppConfig.appTagline,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scan = context.read<ScanController>();
    final notSkin = scan.notSkin;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(notSkin ? Icons.image_not_supported_outlined : Icons.error_outline,
              size: 56, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(notSkin ? 'scan.notSkinTitle'.tr() : 'scan.analysisFailed'.tr(),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(notSkin ? 'scan.notSkinBody'.tr() : message,
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => scan.backToAdjust(),
            child: Text('common.retry'.tr()),
          ),
          TextButton(
            onPressed: () => scan.reset(),
            child: Text('common.startOver'.tr()),
          ),
        ],
      ),
    );
  }
}
