// Typed models for the /predict response.

class ClassResult {
  final String code;
  final int index;
  final String name;
  final String commonName;
  final double probability;
  final double resemblancePct;
  final bool malignant;
  final String risk;
  final double? uncertainty;
  final String oneLiner;
  final String patientNote;
  final String clinicianNote;

  ClassResult({
    required this.code,
    required this.index,
    required this.name,
    required this.commonName,
    required this.probability,
    required this.resemblancePct,
    required this.malignant,
    required this.risk,
    required this.uncertainty,
    required this.oneLiner,
    required this.patientNote,
    required this.clinicianNote,
  });

  factory ClassResult.fromJson(Map<String, dynamic> j) => ClassResult(
        code: j['code'] as String,
        index: (j['index'] as num).toInt(),
        name: j['name'] as String,
        commonName: j['common_name'] as String? ?? j['name'] as String,
        probability: (j['probability'] as num).toDouble(),
        resemblancePct: (j['resemblance_pct'] as num).toDouble(),
        malignant: j['malignant'] as bool? ?? false,
        risk: j['risk'] as String? ?? 'low',
        uncertainty: (j['uncertainty'] as num?)?.toDouble(),
        oneLiner: j['one_liner'] as String? ?? '',
        patientNote: j['patient_note'] as String? ?? '',
        clinicianNote: j['clinician_note'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'index': index,
        'name': name,
        'common_name': commonName,
        'probability': probability,
        'resemblance_pct': resemblancePct,
        'malignant': malignant,
        'risk': risk,
        'uncertainty': uncertainty,
        'one_liner': oneLiner,
        'patient_note': patientNote,
        'clinician_note': clinicianNote,
      };
}

class Confidence {
  final double topProbability;
  final double entropyNormalised;
  final String level; // high | moderate | low
  final bool mcDropoutAvailable;
  final double? meanUncertainty;

  Confidence({
    required this.topProbability,
    required this.entropyNormalised,
    required this.level,
    required this.mcDropoutAvailable,
    required this.meanUncertainty,
  });

  factory Confidence.fromJson(Map<String, dynamic> j) => Confidence(
        topProbability: (j['top_probability'] as num).toDouble(),
        entropyNormalised: (j['entropy_normalised'] as num).toDouble(),
        level: j['level'] as String? ?? 'low',
        mcDropoutAvailable: j['mc_dropout_available'] as bool? ?? false,
        meanUncertainty: (j['mean_uncertainty'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'top_probability': topProbability,
        'entropy_normalised': entropyNormalised,
        'level': level,
        'mc_dropout_available': mcDropoutAvailable,
        'mean_uncertainty': meanUncertainty,
      };
}

class Urgency {
  final String band; // urgent | routine-soon | monitor
  final String label;
  final String message;

  Urgency({required this.band, required this.label, required this.message});

  factory Urgency.fromJson(Map<String, dynamic> j) => Urgency(
        band: j['band'] as String? ?? 'monitor',
        label: j['label'] as String? ?? '',
        message: j['message'] as String? ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'band': band, 'label': label, 'message': message};
}

class Prediction {
  final bool mock;
  final String modelConfig;
  final String topCode;
  final String topName;
  final String topCommonName;
  final double topProbability;
  final String topRisk;
  final bool topMalignant;
  final List<ClassResult> classes; // in label-index order
  final List<String> ranking; // codes, highest first
  final double malignantProbability;
  final Confidence confidence;
  final Urgency urgency;
  final double latencyMs;
  final DateTime timestamp;

  Prediction({
    required this.mock,
    required this.modelConfig,
    required this.topCode,
    required this.topName,
    required this.topCommonName,
    required this.topProbability,
    required this.topRisk,
    required this.topMalignant,
    required this.classes,
    required this.ranking,
    required this.malignantProbability,
    required this.confidence,
    required this.urgency,
    required this.latencyMs,
    required this.timestamp,
  });

  /// Classes sorted by probability, highest first.
  List<ClassResult> get ranked {
    final list = [...classes];
    list.sort((a, b) => b.probability.compareTo(a.probability));
    return list;
  }

  ClassResult get top =>
      classes.firstWhere((c) => c.code == topCode, orElse: () => ranked.first);

  factory Prediction.fromJson(Map<String, dynamic> j) {
    final top = j['top'] as Map<String, dynamic>;
    return Prediction(
      mock: j['mock'] as bool? ?? false,
      modelConfig: j['model_config_name'] as String? ??
          j['model_config'] as String? ??
          '',
      topCode: top['code'] as String,
      topName: top['name'] as String,
      topCommonName: top['common_name'] as String? ?? top['name'] as String,
      topProbability: (top['probability'] as num).toDouble(),
      topRisk: top['risk'] as String? ?? 'low',
      topMalignant: top['malignant'] as bool? ?? false,
      classes: (j['classes'] as List)
          .map((e) => ClassResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      ranking: (j['ranking'] as List).map((e) => e.toString()).toList(),
      malignantProbability:
          (j['malignant_probability'] as num?)?.toDouble() ?? 0,
      confidence: Confidence.fromJson(j['confidence'] as Map<String, dynamic>),
      urgency: Urgency.fromJson(j['urgency'] as Map<String, dynamic>),
      latencyMs: (j['latency_ms'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mock': mock,
        'model_config': modelConfig,
        'top': {
          'code': topCode,
          'name': topName,
          'common_name': topCommonName,
          'probability': topProbability,
          'risk': topRisk,
          'malignant': topMalignant,
        },
        'classes': classes.map((c) => c.toJson()).toList(),
        'ranking': ranking,
        'malignant_probability': malignantProbability,
        'confidence': confidence.toJson(),
        'urgency': urgency.toJson(),
        'latency_ms': latencyMs,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Prediction.fromStored(Map<String, dynamic> j) {
    final p = Prediction.fromJson(j);
    return Prediction(
      mock: p.mock,
      modelConfig: p.modelConfig,
      topCode: p.topCode,
      topName: p.topName,
      topCommonName: p.topCommonName,
      topProbability: p.topProbability,
      topRisk: p.topRisk,
      topMalignant: p.topMalignant,
      classes: p.classes,
      ranking: p.ranking,
      malignantProbability: p.malignantProbability,
      confidence: p.confidence,
      urgency: p.urgency,
      latencyMs: p.latencyMs,
      timestamp:
          DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
