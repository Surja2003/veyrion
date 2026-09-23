import 'package:flutter/foundation.dart';

import '../models/prediction.dart';
import '../services/api.dart';
import '../services/image_ops.dart';
import 'app_controller.dart';

enum ScanStage { capture, adjust, metadata, analysing, result, error }

/// Drives one scan: image -> fine-tune -> metadata -> predict -> result.
class ScanController extends ChangeNotifier {
  ScanController(this._app);

  final AppController _app;
  final ImageOps ops = ImageOps();

  ScanStage stage = ScanStage.capture;

  Uint8List? originalBytes; // as captured/cropped
  Uint8List? enhancedBytes; // after fine-tune sliders
  String filename = 'lesion.jpg';

  // Fine-tune params
  double brightness = 0, contrast = 0, saturation = 0, sharpen = 0;
  bool autoWhiteBalance = false;
  bool enhancing = false;

  // Metadata
  double? age;
  String sex = 'unknown';
  String localization = 'unknown';
  bool mcDropout = true;

  Prediction? result;
  String? error;

  Uint8List? get workingImage => enhancedBytes ?? originalBytes;

  void reset() {
    stage = ScanStage.capture;
    originalBytes = null;
    enhancedBytes = null;
    brightness = contrast = saturation = sharpen = 0;
    autoWhiteBalance = false;
    age = null;
    sex = 'unknown';
    localization = 'unknown';
    result = null;
    error = null;
    notifyListeners();
  }

  Future<void> setImage(Uint8List bytes, {String name = 'lesion.jpg'}) async {
    // Downscale once at intake so crop/enhance/preview stay smooth on phones.
    enhancedBytes = null;
    filename = name;
    stage = ScanStage.adjust;
    notifyListeners();
    try {
      originalBytes = await ops.prepareWorking(bytes);
    } catch (_) {
      originalBytes = bytes; // fall back to the raw bytes on any decode issue
    }
    notifyListeners();
  }

  /// Called after the crop widget returns cropped bytes.
  void setCropped(Uint8List bytes) {
    originalBytes = bytes;
    enhancedBytes = null;
    notifyListeners();
    applyEnhancements();
  }

  Future<void> applyEnhancements() async {
    if (originalBytes == null) return;
    enhancing = true;
    notifyListeners();
    try {
      if (brightness == 0 &&
          contrast == 0 &&
          saturation == 0 &&
          sharpen == 0 &&
          !autoWhiteBalance) {
        enhancedBytes = null;
      } else {
        enhancedBytes = await ops.enhance(
          originalBytes!,
          brightness: brightness,
          contrast: contrast,
          saturation: saturation,
          sharpen: sharpen,
          autoWhiteBalance: autoWhiteBalance,
        );
      }
    } finally {
      enhancing = false;
      notifyListeners();
    }
  }

  void goToMetadata() {
    stage = ScanStage.metadata;
    notifyListeners();
  }

  void backToAdjust() {
    stage = ScanStage.adjust;
    notifyListeners();
  }

  Future<void> analyse() async {
    if (workingImage == null || _app.token == null) return;
    stage = ScanStage.analysing;
    error = null;
    notifyListeners();
    try {
      final upload = await ops.prepareForUpload(workingImage!);
      final pred = await _app.api.predict(
        token: _app.token!,
        imageBytes: upload,
        filename: filename,
        age: age,
        sex: sex,
        localization: localization,
        mcDropout: mcDropout,
      );
      result = pred;
      stage = ScanStage.result;
      notifyListeners();
      await _app.addToHistory(pred);
    } on ApiException catch (e) {
      error = e.message;
      stage = ScanStage.error;
      notifyListeners();
    } catch (e) {
      error = 'Analysis failed: $e';
      stage = ScanStage.error;
      notifyListeners();
    }
  }
}
