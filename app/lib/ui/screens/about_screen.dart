import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../state/app_controller.dart';
import '../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final classes = app.meta.classes;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Learn',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const _ABCDECard(),
              const SizedBox(height: 16),
              _ModelCard(app: app),
              const SizedBox(height: 16),
              if (classes.isNotEmpty) ...[
                const SectionHeader('The 7 lesion types'),
                ...classes.map((c) => _ClassTile(
                      title: c.name,
                      common: c.commonName,
                      risk: c.risk,
                      malignant: c.malignant,
                      patient: c.patientNote,
                      clinician: c.clinicianNote,
                    )),
                const SizedBox(height: 16),
              ],
              const _ReferencesCard(),
              const SizedBox(height: 16),
              const DisclaimerBanner(long: true),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ABCDECard extends StatelessWidget {
  const _ABCDECard();
  @override
  Widget build(BuildContext context) {
    final items = {
      'A — Asymmetry': 'One half does not match the other.',
      'B — Border': 'Edges are ragged, notched, or blurred.',
      'C — Colour': 'More than one colour, or uneven shades.',
      'D — Diameter': 'Larger than ~6 mm (a pencil eraser).',
      'E — Evolving': 'Changing in size, shape, colour, or symptoms.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('The ABCDE self-check'),
            Text(
                'A simple way to decide when to get a mole checked, from dermatology guidance:',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            ...items.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(e.value),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final card = app.meta.modelCard;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('About the model'),
            Text(
              'Veyrion uses a five-backbone feature-fusion network (Swin-Tiny, ConvNeXt-Base, '
              'EfficientNet-B4, DenseNet-201, and a multi-scale ResNet-34) combined with '
              'patient metadata, trained on HAM10000 with lesion-level grouped validation.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            _stat(context, 'Validation accuracy',
                '${((card?.accuracy ?? AppConfig.modelAccuracy) * 100).toStringAsFixed(1)}%'),
            _stat(context, 'Macro-F1',
                (card?.macroF1 ?? AppConfig.modelMacroF1).toStringAsFixed(4)),
            _stat(context, 'Melanoma recall',
                '${((card?.melanomaRecall ?? AppConfig.modelMelanomaRecall) * 100).toStringAsFixed(1)}%'),
            if (card != null && card.dataset.isNotEmpty)
              _stat(context, 'Dataset', card.dataset),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.riskModerate.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                card?.keyCaveat ??
                    'This is a controlled-benchmark model, not a clinically validated device. '
                        'Its melanoma sensitivity is limited — never use it to rule out cancer.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(k)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({
    required this.title,
    required this.common,
    required this.risk,
    required this.malignant,
    required this.patient,
    required this.clinician,
  });
  final String title, common, risk, patient, clinician;
  final bool malignant;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
            malignant ? Icons.coronavirus_outlined : Icons.spa_outlined,
            color: AppTheme.risk(risk)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(common, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: RiskBadge(risk: risk, compact: true),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(patient, style: const TextStyle(height: 1.4)),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Clinical: $clinician',
                style: TextStyle(
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _ReferencesCard extends StatelessWidget {
  const _ReferencesCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Source & credits'),
            Text(
              'Based on: "Multi-Backbone Feature Fusion for Multi-Class Skin Lesion '
              'Classification" (V. Vaibhav & N. Das). Dataset: HAM10000 '
              '(Tschandl et al., 2018).',
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
