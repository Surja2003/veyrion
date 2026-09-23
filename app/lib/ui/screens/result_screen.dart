import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/prediction.dart';
import '../../state/app_controller.dart';
import '../../state/scan_controller.dart';
import '../widgets/common.dart';
import '../widgets/probability_bar.dart';
import 'chat_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scan = context.read<ScanController>();
    final app = context.watch<AppController>();
    final pred = scan.result;
    if (pred == null) {
      return Scaffold(body: Center(child: Text('result.noResult'.tr())));
    }
    final isClinic = app.isClinic;

    return Scaffold(
      appBar: AppBar(
        title: Text('result.title'.tr()),
        actions: [
          IconButton(
            tooltip: 'result.copySummary'.tr(),
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: _summaryText(pred, isClinic)));
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('result.copied'.tr())));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (pred.mock) const _MockWarning(),
                if (pred.mock) const SizedBox(height: 12),

                _HeadlineCard(pred: pred, image: scan.workingImage),
                const SizedBox(height: 16),

                _UrgencyCard(pred: pred),
                const SizedBox(height: 16),

                // Patient reassurance is shown to BOTH roles (nothing hidden),
                // but it leads for patients and is framed as guidance for clinics.
                _ReassuranceCard(isClinic: isClinic),
                const SizedBox(height: 16),

                RepaintBoundary(child: _AllProbabilities(pred: pred)),
                const SizedBox(height: 16),

                _ConfidenceCard(pred: pred),
                const SizedBox(height: 16),

                _TopClassDetail(pred: pred, isClinic: isClinic),
                const SizedBox(height: 16),

                // The melanoma-miss caveat — always shown, it is safety-critical.
                _SafetyCaveat(pred: pred),
                const SizedBox(height: 16),

                if (isClinic) ...[
                  _ClinicalNotes(pred: pred),
                  const SizedBox(height: 16),
                ],

                const DisclaimerBanner(long: true),
                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(grounding: pred),
                    ),
                  ),
                  icon: const Icon(Icons.forum_outlined),
                  label: Text('result.askAssistant'.tr()),
                ),
                const SizedBox(height: 10),

                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text('result.newScan'.tr()),
                ),
                const SizedBox(height: 8),
                Text(
                  'Latency ${pred.latencyMs.toStringAsFixed(0)} ms · ${pred.modelConfig}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
class _MockWarning extends StatelessWidget {
  const _MockWarning();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: c.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'MOCK RESULT — the server has no trained weights loaded, so these numbers '
              'are placeholders for testing the app, not real predictions.',
              style: TextStyle(
                  color: c.onErrorContainer, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.pred, this.image});
  final Prediction pred;
  final Uint8List? image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.risk(pred.topRisk);
    final img = image;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (img != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(img,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    gaplessPlayback: true),
              ),
            if (img != null) const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Most likely', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(pred.topName,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(pred.topCommonName,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${(pred.topProbability * 100).toStringAsFixed(1)}%',
                          style: theme.textTheme.headlineSmall?.copyWith(
                              color: color, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Text('resemblance', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 10),
                  RiskBadge(risk: pred.topRisk),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgencyCard extends StatelessWidget {
  const _UrgencyCard({required this.pred});
  final Prediction pred;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.risk(pred.urgency.band);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_outlined, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(pred.urgency.label,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(pred.urgency.message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(
            'Combined chance of a cancerous / pre-cancerous type: '
            '${(pred.malignantProbability * 100).toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ReassuranceCard extends StatelessWidget {
  const _ReassuranceCard({required this.isClinic});
  final bool isClinic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Card(
      color: c.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_outline, color: c.primary, size: 20),
                const SizedBox(width: 8),
                Text(isClinic ? 'What the patient is told' : 'Read this first',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Text(Disclaimers.patientReassurance,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _AllProbabilities extends StatelessWidget {
  const _AllProbabilities({required this.pred});
  final Prediction pred;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('How much it resembles each type'),
            Text(
              'Every class is shown — nothing is hidden. Percentages are the model’s '
              'estimated resemblance and add up to 100%.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            ...pred.ranked.map((r) => ProbabilityBar(
                  result: r,
                  highlighted: r.code == pred.topCode,
                  onTap: () => _showClassSheet(context, r),
                )),
          ],
        ),
      ),
    );
  }
}

void _showClassSheet(BuildContext context, ClassResult r) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.name,
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              RiskBadge(risk: r.risk, compact: true),
            ],
          ),
          Text(r.commonName,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Text('${r.resemblancePct.toStringAsFixed(1)}% resemblance',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  color: AppTheme.risk(r.risk), fontWeight: FontWeight.bold)),
          if (r.uncertainty != null)
            Text('± ${(r.uncertainty! * 100).toStringAsFixed(1)}% uncertainty',
                style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: 16),
          Text('In plain language',
              style: Theme.of(ctx)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(r.patientNote, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 16),
          Text('Clinical note',
              style: Theme.of(ctx)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(r.clinicianNote, style: const TextStyle(height: 1.4)),
        ],
      ),
    ),
  );
}

class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.pred});
  final Prediction pred;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conf = pred.confidence;
    final level = conf.level;
    final color = level == 'high'
        ? AppTheme.riskLow
        : level == 'moderate'
            ? AppTheme.riskModerate
            : AppTheme.riskHigh;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionHeader('Model confidence')),
                Pill(level.toUpperCase(), icon: Icons.speed, color: color),
              ],
            ),
            const SizedBox(height: 4),
            _metric(context, 'Top resemblance',
                '${(conf.topProbability * 100).toStringAsFixed(1)}%'),
            _metric(context, 'Spread across classes (entropy)',
                '${(conf.entropyNormalised * 100).toStringAsFixed(0)}%'),
            if (conf.mcDropoutAvailable && conf.meanUncertainty != null)
              _metric(context, 'Average uncertainty (MC-Dropout)',
                  '± ${(conf.meanUncertainty! * 100).toStringAsFixed(1)}%'),
            const SizedBox(height: 8),
            Text(
              level == 'low'
                  ? 'Low confidence: the model is unsure. Treat this as a nudge to get a '
                      'professional opinion, not as an answer.'
                  : level == 'moderate'
                      ? 'Moderate confidence. Useful signal, but confirm with a clinician.'
                      : 'Higher confidence — but confidence is not correctness. Still confirm anything concerning.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _TopClassDetail extends StatelessWidget {
  const _TopClassDetail({required this.pred, required this.isClinic});
  final Prediction pred;
  final bool isClinic;

  @override
  Widget build(BuildContext context) {
    final top = pred.top;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('About "${top.name}"'),
            Text('In plain language',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(top.patientNote, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 14),
            Text(isClinic ? 'Clinical note' : 'For your doctor',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(top.clinicianNote, style: const TextStyle(height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _SafetyCaveat extends StatelessWidget {
  const _SafetyCaveat({required this.pred});
  final Prediction pred;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    // Especially important when the top pick is benign but melanoma is plausible.
    final melResemblance = pred.classes
        .firstWhere((e) => e.code == 'mel', orElse: () => pred.ranked.first)
        .resemblancePct;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.riskModerate.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: AppTheme.riskModerate),
              const SizedBox(width: 8),
              Text('Important safety note',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This model correctly flags only about ${(AppConfig.modelMelanomaRecall * 100).toStringAsFixed(0)}% '
            'of true melanomas — its most common mistake is calling a melanoma a harmless mole. '
            'A low melanoma score (here ${melResemblance.toStringAsFixed(1)}%) does NOT rule out cancer. '
            'If a spot is new, changing, or worrying you, see a dermatologist regardless of this result.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ClinicalNotes extends StatelessWidget {
  const _ClinicalNotes({required this.pred});
  final Prediction pred;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Clinical decision context'),
            _line(theme, 'Model',
                '${pred.modelConfig} · 5-backbone fusion + metadata'),
            _line(theme, 'Validation accuracy',
                '${(AppConfig.modelAccuracy * 100).toStringAsFixed(1)}% (lesion-grouped)'),
            _line(theme, 'Macro-F1', AppConfig.modelMacroF1.toStringAsFixed(4)),
            _line(theme, 'Melanoma recall',
                '${(AppConfig.modelMelanomaRecall * 100).toStringAsFixed(1)}% — under-sensitive'),
            const SizedBox(height: 8),
            Text(
              'Dominant confusions in validation: MEL→NV (53), BKL→MEL (17), AKIEC→BKL (7). '
              'Correlate with dermoscopy, history and ABCDE; low melanoma probability is not '
              'a rule-out. Consider biopsy on clinical suspicion irrespective of model output.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(ThemeData theme, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 150, child: Text(k, style: theme.textTheme.bodySmall)),
            Expanded(
                child: Text(v,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

String _summaryText(Prediction p, bool isClinic) {
  final b = StringBuffer();
  b.writeln('Veyrion skin-lesion screening result');
  b.writeln('Generated: ${p.timestamp}');
  if (p.mock) b.writeln('*** MOCK RESULT — no model weights loaded ***');
  b.writeln('');
  b.writeln('Most likely: ${p.topName} (${p.topCommonName}) — '
      '${(p.topProbability * 100).toStringAsFixed(1)}% resemblance');
  b.writeln('Recommended action: ${p.urgency.label}');
  b.writeln('Combined malignant/pre-malignant probability: '
      '${(p.malignantProbability * 100).toStringAsFixed(1)}%');
  b.writeln('Model confidence: ${p.confidence.level}');
  b.writeln('');
  b.writeln('Full breakdown:');
  for (final r in p.ranked) {
    b.writeln('  ${r.name}: ${r.resemblancePct.toStringAsFixed(1)}%'
        '${r.uncertainty != null ? ' (±${(r.uncertainty! * 100).toStringAsFixed(1)}%)' : ''}'
        '${r.malignant ? '  [malignant/pre-malignant]' : ''}');
  }
  b.writeln('');
  b.writeln('NOTE: Screening aid only, not a diagnosis. Melanoma recall ~69% — '
      'a low melanoma score does not rule out cancer. Consult a clinician.');
  return b.toString();
}
