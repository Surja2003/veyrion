// Options + class catalogue + model card from /meta/options.

class ClassInfo {
  final String code;
  final int index;
  final String name;
  final String commonName;
  final bool malignant;
  final String risk;
  final String oneLiner;
  final String patientNote;
  final String clinicianNote;

  ClassInfo({
    required this.code,
    required this.index,
    required this.name,
    required this.commonName,
    required this.malignant,
    required this.risk,
    required this.oneLiner,
    required this.patientNote,
    required this.clinicianNote,
  });

  factory ClassInfo.fromJson(Map<String, dynamic> j) => ClassInfo(
        code: j['code'] as String,
        index: (j['index'] as num).toInt(),
        name: j['name'] as String,
        commonName: j['common_name'] as String? ?? j['name'] as String,
        malignant: j['malignant'] as bool? ?? false,
        risk: j['risk'] as String? ?? 'low',
        oneLiner: j['one_liner'] as String? ?? '',
        patientNote: j['patient_note'] as String? ?? '',
        clinicianNote: j['clinician_note'] as String? ?? '',
      );
}

class ModelCard {
  final String dataset;
  final String config;
  final double accuracy;
  final double macroF1;
  final double melanomaRecall;
  final Map<String, double> perClassF1;
  final String keyCaveat;

  ModelCard({
    required this.dataset,
    required this.config,
    required this.accuracy,
    required this.macroF1,
    required this.melanomaRecall,
    required this.perClassF1,
    required this.keyCaveat,
  });

  factory ModelCard.fromJson(Map<String, dynamic> j) => ModelCard(
        dataset: j['dataset'] as String? ?? '',
        config: j['config'] as String? ?? '',
        accuracy: (j['accuracy'] as num?)?.toDouble() ?? 0,
        macroF1: (j['macro_f1'] as num?)?.toDouble() ?? 0,
        melanomaRecall: (j['melanoma_recall'] as num?)?.toDouble() ?? 0,
        perClassF1: ((j['per_class_f1'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        keyCaveat: j['key_caveat'] as String? ?? '',
      );
}

class MetaOptions {
  final List<String> sexOptions;
  final List<String> localizationOptions;
  final List<ClassInfo> classes;
  final ModelCard? modelCard;

  MetaOptions({
    required this.sexOptions,
    required this.localizationOptions,
    required this.classes,
    required this.modelCard,
  });

  factory MetaOptions.fromJson(Map<String, dynamic> j) => MetaOptions(
        sexOptions: (j['sex'] as List).map((e) => e.toString()).toList(),
        localizationOptions:
            (j['localization'] as List).map((e) => e.toString()).toList(),
        classes: (j['classes'] as List)
            .map((e) => ClassInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        modelCard: j['model_card'] != null
            ? ModelCard.fromJson(j['model_card'] as Map<String, dynamic>)
            : null,
      );

  /// Sensible offline fallback so the app can render forms even if /meta fails.
  factory MetaOptions.fallback() => MetaOptions(
        sexOptions: const ['unknown', 'male', 'female'],
        localizationOptions: const [
          'unknown',
          'abdomen',
          'acral',
          'back',
          'chest',
          'ear',
          'face',
          'foot',
          'genital',
          'hand',
          'lower extremity',
          'neck',
          'scalp',
          'trunk',
          'upper extremity',
        ],
        classes: const [],
        modelCard: null,
      );
}
