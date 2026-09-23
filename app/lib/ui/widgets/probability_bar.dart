import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/prediction.dart';

/// A single class row: name, resemblance %, animated bar, optional uncertainty.
class ProbabilityBar extends StatelessWidget {
  const ProbabilityBar({
    super.key,
    required this.result,
    this.highlighted = false,
    this.showUncertainty = true,
    this.onTap,
  });

  final ClassResult result;
  final bool highlighted;
  final bool showUncertainty;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.risk(result.risk);
    final pct = result.resemblancePct;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          highlighted ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                if (result.malignant)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.coronavirus_outlined,
                        size: 15,
                        color: AppTheme.riskHigh.withValues(alpha: 0.8)),
                  ),
                Text('${pct.toStringAsFixed(1)}%',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700, color: color)),
              ],
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Stack(
                children: [
                  Container(
                    height: 9,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 9,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.7), color],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (showUncertainty && result.uncertainty != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '± ${(result.uncertainty! * 100).toStringAsFixed(1)}% model uncertainty',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
