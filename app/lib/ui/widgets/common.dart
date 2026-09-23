import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';

/// Reusable small UI pieces.

class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key, this.long = false});
  final bool long;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: c.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              long ? Disclaimers.long : Disclaimers.short,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.onTertiaryContainer, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class RiskBadge extends StatelessWidget {
  const RiskBadge(
      {super.key, required this.risk, this.label, this.compact = false});
  final String risk;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.risk(risk);
    final text = label ?? _riskLabel(risk);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_riskIcon(risk), size: compact ? 14 : 16, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 12 : 13)),
        ],
      ),
    );
  }

  static String _riskLabel(String r) {
    switch (r) {
      case 'high':
        return 'Higher concern';
      case 'moderate':
        return 'Moderate';
      default:
        return 'Low concern';
    }
  }

  static IconData _riskIcon(String r) {
    switch (r) {
      case 'high':
        return Icons.priority_high;
      case 'moderate':
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle_outline;
    }
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 5)
          ],
          Text(text,
              style: TextStyle(
                  color: c, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
