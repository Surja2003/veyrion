/// Runtime configuration. The API base URL is user-configurable in Settings
/// and persisted; this holds the compile-time defaults.
class AppConfig {
  AppConfig._();

  /// Default API base URL. Override at build time with:
  ///   flutter run --dart-define=DARM_API_BASE=https://your-space.hf.space
  static const String defaultApiBase = String.fromEnvironment(
    'DARM_API_BASE',
    defaultValue: 'http://137.23.47.128',
  );

  static const String appName = 'Veyrion';
  static const String appTagline = 'Precision in Every Insight';

  /// Model context surfaced honestly in the UI.
  static const double modelAccuracy = 0.9062;
  static const double modelMacroF1 = 0.8257;
  static const double modelMelanomaRecall = 0.6891;
}

/// Global, non-negotiable disclaimer text reused across the app.
class Disclaimers {
  Disclaimers._();

  static const String short =
      'Veyrion is a decision-support tool — not a medical diagnosis. Always consult a qualified clinician.';

  static const String long =
      'Veyrion is an AI screening aid trained on the HAM10000 dataset. It is NOT a '
      'medical device and has not been clinically validated. Its results can be '
      'wrong — in particular it correctly identifies only about 69% of true '
      'melanomas, so it must never be used to rule out skin cancer. Use it to '
      'help decide whether to see a dermatologist, not as a substitute for one.';

  static const String patientReassurance =
      'Take a breath. This is a screening estimate from a computer model, not a '
      'diagnosis. Whatever it shows, the sensible next step is calm and simple: '
      'if anything looks concerning, book a dermatologist. Most skin spots are '
      'harmless, and even the serious ones are usually very treatable when found early.';
}
