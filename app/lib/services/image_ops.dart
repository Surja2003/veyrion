import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Image acquisition + the "fine-tune" enhancement pipeline.
/// Everything is byte-based (Uint8List) so it works on web, Android and Windows.
class ImageOps {
  final ImagePicker _picker = ImagePicker();

  bool get cameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  bool get _useImagePickerForGallery =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<Uint8List?> pickFromGallery() async {
    if (_useImagePickerForGallery) {
      final x = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 95,
      );
      return x == null ? null : await x.readAsBytes();
    }
    // Desktop: file_selector
    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    return file == null ? null : await file.readAsBytes();
  }

  Future<Uint8List?> captureFromCamera() async {
    if (!cameraSupported) return null;
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );
    return x == null ? null : await x.readAsBytes();
  }

  // ------------------------------------------------------------------ //
  //  Enhancement ("fine-tune") — pure Dart, runs on every platform.
  //  Values are 0-centred sliders in the UI: 0 = no change.
  // ------------------------------------------------------------------ //
  Future<Uint8List> enhance(
    Uint8List input, {
    double brightness = 0, // -100..100
    double contrast = 0, // -100..100
    double saturation = 0, // -100..100
    double sharpen = 0, // 0..100
    bool autoWhiteBalance = false,
  }) async {
    return compute(_enhanceIsolate, {
      'bytes': input,
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'sharpen': sharpen,
      'awb': autoWhiteBalance,
    });
  }

  /// Downscale + re-encode to keep uploads small and consistent (long edge 1024).
  Future<Uint8List> prepareForUpload(Uint8List input) async {
    return compute(_prepareIsolate, input);
  }

  /// Intake downscale: run ONCE when an image enters the pipeline so the
  /// crop/enhance/preview steps operate on a light image (long edge 1600) and
  /// stay smooth on mid-range phones. Keeps ample detail for a 448px model.
  Future<Uint8List> prepareWorking(Uint8List input) async {
    return compute(_workingIsolate, input);
  }

  /// Focus/sharpness score (variance of the Laplacian) — higher = crisper.
  /// Used by the multi-shot flow to auto-pick the least-blurry frame.
  Future<double> sharpnessScore(Uint8List input) async {
    return compute(_sharpnessIsolate, input);
  }

  /// Given 2–3 candidate shots, automatically return the sharpest one plus its
  /// index and per-frame scores (so the UI can briefly show what it chose).
  Future<BestShot> pickSharpest(List<Uint8List> shots) async {
    if (shots.isEmpty) {
      throw ArgumentError('pickSharpest needs at least one image');
    }
    if (shots.length == 1) {
      return BestShot(bytes: shots.first, index: 0, scores: const [1.0]);
    }
    final scores = await compute(_sharpnessBatchIsolate, shots);
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    return BestShot(bytes: shots[best], index: best, scores: scores);
  }

  /// Pick multiple images from the gallery (mobile/web); the caller auto-selects
  /// the sharpest via [pickSharpest].
  Future<List<Uint8List>> pickMultipleFromGallery({int limit = 3}) async {
    if (_useImagePickerForGallery) {
      final xs = await _picker.pickMultiImage(
        maxWidth: 2048,
        imageQuality: 95,
        limit: limit,
      );
      final out = <Uint8List>[];
      for (final x in xs.take(limit)) {
        out.add(await x.readAsBytes());
      }
      return out;
    }
    // Desktop: file_selector multi-select.
    const typeGroup = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
    );
    final files = await openFiles(acceptedTypeGroups: [typeGroup]);
    final out = <Uint8List>[];
    for (final f in files.take(limit)) {
      out.add(await f.readAsBytes());
    }
    return out;
  }
}

/// Result of the auto pick-best step.
class BestShot {
  BestShot({required this.bytes, required this.index, required this.scores});
  final Uint8List bytes;
  final int index;
  final List<double> scores;
}

List<double> _sharpnessBatchIsolate(List<Uint8List> shots) {
  return [for (final b in shots) _sharpnessIsolate(b)];
}

double _sharpnessIsolate(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return 0;
  // Downscale for speed; blur measure is scale-tolerant at ~320px.
  final small = img.copyResize(decoded,
      width: decoded.width >= decoded.height ? 320 : null,
      height: decoded.height > decoded.width ? 320 : null,
      interpolation: img.Interpolation.average);
  final gray = img.grayscale(small);
  final w = gray.width, h = gray.height;
  // Read luma once into a flat buffer.
  final lum = List<double>.filled(w * h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      lum[y * w + x] = gray.getPixel(x, y).r.toDouble();
    }
  }
  // 4-neighbour Laplacian, then variance of the response.
  double sum = 0, sumSq = 0;
  int n = 0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final lap =
          (lum[i - 1] + lum[i + 1] + lum[i - w] + lum[i + w]) - 4 * lum[i];
      sum += lap;
      sumSq += lap * lap;
      n++;
    }
  }
  if (n == 0) return 0;
  final mean = sum / n;
  return (sumSq / n) - (mean * mean); // variance
}

Uint8List _enhanceIsolate(Map<String, dynamic> args) {
  final decoded = img.decodeImage(args['bytes'] as Uint8List);
  if (decoded == null) return args['bytes'] as Uint8List;
  var im = decoded;

  final b = (args['brightness'] as double);
  final c = (args['contrast'] as double);
  final s = (args['saturation'] as double);
  final sh = (args['sharpen'] as double);
  final awb = args['awb'] as bool;

  if (awb) {
    im = img.normalize(im, min: 0, max: 255);
  }
  if (b != 0 || c != 0 || s != 0) {
    im = img.adjustColor(
      im,
      brightness: 1.0 + b / 100.0,
      contrast: 1.0 + c / 100.0,
      saturation: 1.0 + s / 100.0,
    );
  }
  if (sh > 0) {
    final amount = sh / 100.0;
    // Unsharp-style kernel scaled by amount.
    final k = [
      0.0,
      -amount,
      0.0,
      -amount,
      1 + 4 * amount,
      -amount,
      0.0,
      -amount,
      0.0,
    ];
    im = img.convolution(im, filter: k, div: 1.0);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 95));
}

Uint8List _prepareIsolate(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final resized = (decoded.width > 1024 || decoded.height > 1024)
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1024 : null,
          height: decoded.height > decoded.width ? 1024 : null,
          interpolation: img.Interpolation.cubic,
        )
      : decoded;
  return Uint8List.fromList(img.encodeJpg(resized, quality: 92));
}

Uint8List _workingIsolate(Uint8List bytes) {
  const maxEdge = 1600;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  if (decoded.width <= maxEdge && decoded.height <= maxEdge) {
    return bytes; // already light enough
  }
  final resized = img.copyResize(
    decoded,
    width: decoded.width >= decoded.height ? maxEdge : null,
    height: decoded.height > decoded.width ? maxEdge : null,
    interpolation: img.Interpolation.average,
  );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 92));
}
