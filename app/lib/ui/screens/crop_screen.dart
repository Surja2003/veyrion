import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// Full-screen cropper. Returns cropped bytes via Navigator.pop, or null.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.image});
  final Uint8List image;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _controller = CropController();
  bool _cropping = false;
  bool _square = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Crop to the lesion'),
        actions: [
          IconButton(
            tooltip: _square ? 'Free aspect' : 'Square',
            icon: Icon(_square ? Icons.crop_square : Icons.crop_free),
            onPressed: () => setState(() => _square = !_square),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              controller: _controller,
              image: widget.image,
              aspectRatio: _square ? 1 : null,
              initialRectBuilder:
                  InitialRectBuilder.withSizeAndRatio(size: 0.85),
              baseColor: Colors.black,
              maskColor: Colors.black.withValues(alpha: 0.6),
              cornerDotBuilder: (size, edge) =>
                  const DotControl(color: Colors.white),
              onCropped: (result) {
                setState(() => _cropping = false);
                if (result is CropSuccess) {
                  Navigator.of(context).pop(result.croppedImage);
                } else {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: _cropping ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style:
                        FilledButton.styleFrom(backgroundColor: scheme.primary),
                    onPressed: _cropping
                        ? null
                        : () {
                            setState(() => _cropping = true);
                            _controller.crop();
                          },
                    icon: _cropping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: const Text('Apply crop'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
