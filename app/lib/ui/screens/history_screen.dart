import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/prediction.dart';
import '../../state/app_controller.dart';
import '../widgets/common.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final history = app.history;
    final fmt = DateFormat('d MMM yyyy · HH:mm');

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: history.isEmpty
              ? _empty(context)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Row(
                        children: [
                          Expanded(
                            child: Text('Scan history (${history.length})',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                          TextButton.icon(
                            onPressed: () => _confirmClear(context, app),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Clear'),
                          ),
                        ],
                      );
                    }
                    final p = history[i - 1];
                    return _HistoryTile(
                        pred: p, subtitle: fmt.format(p.timestamp));
                  },
                ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('No scans yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
              'Your past results will appear here, stored only on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, AppController app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
            'This permanently removes saved results from this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) await app.clearHistory();
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.pred, required this.subtitle});
  final Prediction pred;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.risk(pred.topRisk);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            pred.topMalignant ? Icons.coronavirus_outlined : Icons.spa_outlined,
            color: color,
          ),
        ),
        title: Text(
            '${pred.topName} · ${pred.topProbability >= 0 ? (pred.topProbability * 100).toStringAsFixed(1) : ''}%'),
        subtitle: Text('$subtitle${pred.mock ? ' · mock' : ''}'),
        trailing: RiskBadge(risk: pred.topRisk, compact: true),
        onTap: () => _showDetail(context, pred),
      ),
    );
  }

  void _showDetail(BuildContext context, Prediction p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(p.topName,
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(subtitle, style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            Text(p.urgency.label,
                style: TextStyle(
                    color: AppTheme.risk(p.urgency.band),
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const SectionHeader('Full breakdown'),
            ...p.ranked.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text(r.name)),
                      Text('${r.resemblancePct.toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: AppTheme.risk(r.risk),
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
