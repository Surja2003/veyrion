import 'package:easy_localization/easy_localization.dart';
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
              Text('learn.title'.tr(),
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
                SectionHeader('learn.typesTitle'.tr()),
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
    final items = <String, String>{
      'learn.abcdeA'.tr(): 'learn.abcdeAd'.tr(),
      'learn.abcdeB'.tr(): 'learn.abcdeBd'.tr(),
      'learn.abcdeC'.tr(): 'learn.abcdeCd'.tr(),
      'learn.abcdeD'.tr(): 'learn.abcdeDd'.tr(),
      'learn.abcdeE'.tr(): 'learn.abcdeEd'.tr(),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('learn.abcdeTitle'.tr()),
            Text('learn.abcdeIntro'.tr(),
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
    // Patients get a plain-language explanation; clinics get the technical detail.
    final intro =
        app.isClinic ? 'learn.modelIntroClinic'.tr() : 'learn.modelIntroPatient'.tr();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('learn.modelTitle'.tr()),
            Text(intro, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
            const SizedBox(height: 12),
            _stat(context, 'learn.statAccuracy'.tr(),
                '${((card?.accuracy ?? AppConfig.modelAccuracy) * 100).toStringAsFixed(1)}%'),
            _stat(context, 'learn.statMacroF1'.tr(),
                (card?.macroF1 ?? AppConfig.modelMacroF1).toStringAsFixed(4)),
            _stat(context, 'learn.statMelRecall'.tr(),
                '${((card?.melanomaRecall ?? AppConfig.modelMelanomaRecall) * 100).toStringAsFixed(1)}%'),
            _stat(context, 'learn.statDataset'.tr(), 'learn.datasetShort'.tr()),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.riskModerate.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                card?.keyCaveat ?? 'disclaimer.short'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Two flexible columns so a long value wraps instead of overflowing the row.
  Widget _stat(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: Text(k)),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Text(v,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
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
            child: Text('${'result.clinicalNote'.tr()}: $clinician',
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
            SectionHeader('learn.sourceTitle'.tr()),
            Text('learn.sourceBody'.tr(),
                style:
                    Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4)),
          ],
        ),
      ),
    );
  }
}
