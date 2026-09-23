import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../state/scan_controller.dart';
import '../widgets/common.dart';

/// Patient metadata (age / sex / body site) — the C2 configuration inputs.
class MetadataView extends StatefulWidget {
  const MetadataView({super.key});

  @override
  State<MetadataView> createState() => _MetadataViewState();
}

class _MetadataViewState extends State<MetadataView> {
  @override
  Widget build(BuildContext context) {
    final scan = context.watch<ScanController>();
    final app = context.watch<AppController>();
    final theme = Theme.of(context);
    final locOptions = app.meta.localizationOptions;
    final sexOptions = app.meta.sexOptions;

    String pretty(String s) =>
        s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader('Patient details (optional but recommended)'),
        if (scan.workingImage != null)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(scan.workingImage!,
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                  gaplessPlayback: true),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'These match the clinical fields the model was trained with (age, sex, body '
          'site). They slightly improve accuracy. Leave as “unknown” if unsure.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),

        // Age
        Row(
          children: [
            Text('Age', style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(scan.age == null ? 'Not set' : '${scan.age!.round()} years',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
        Slider(
          value: scan.age ?? 0,
          min: 0,
          max: 100,
          divisions: 100,
          label: scan.age?.round().toString() ?? '—',
          onChanged: (v) => setState(() => scan.age = v == 0 ? null : v),
        ),
        const SizedBox(height: 8),

        // Sex
        DropdownButtonFormField<String>(
          initialValue: scan.sex,
          decoration: const InputDecoration(
              labelText: 'Sex', prefixIcon: Icon(Icons.wc)),
          items: sexOptions
              .map((s) => DropdownMenuItem(value: s, child: Text(pretty(s))))
              .toList(),
          onChanged: (v) => setState(() => scan.sex = v ?? 'unknown'),
        ),
        const SizedBox(height: 16),

        // Localization
        DropdownButtonFormField<String>(
          initialValue: scan.localization,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Body site',
              prefixIcon: Icon(Icons.accessibility_new)),
          items: locOptions
              .map((s) => DropdownMenuItem(value: s, child: Text(pretty(s))))
              .toList(),
          onChanged: (v) => setState(() => scan.localization = v ?? 'unknown'),
        ),
        const SizedBox(height: 16),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Estimate uncertainty (MC-Dropout)'),
          subtitle: const Text(
              'Runs the model several times to show how confident it is. Slightly slower.'),
          value: scan.mcDropout,
          onChanged: (v) => setState(() => scan.mcDropout = v),
        ),
        const SizedBox(height: 16),

        const DisclaimerBanner(),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => scan.backToAdjust(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: app.backendOnline ? () => scan.analyse() : null,
                icon: const Icon(Icons.biotech_outlined),
                label: Text(
                    app.backendOnline ? 'Analyse lesion' : 'Server offline'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
