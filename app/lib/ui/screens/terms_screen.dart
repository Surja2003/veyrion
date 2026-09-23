import 'package:flutter/material.dart';

/// Terms & Conditions for DARM. Shown from Settings and (on first run) as a
/// gate the user must accept. [asGate] adds an Accept button that pops `true`.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key, this.asGate = false, this.onDecision});
  final bool asGate;

  /// When set (gate mode), Accept/Decline call this instead of popping.
  final void Function(bool accepted)? onDecision;

  static const List<(String, String)> _sections = [
    (
      '1. What Veyrion is — and is not',
      'Veyrion is an educational and research screening '
          'aid that uses an AI model to estimate how much a skin-lesion image resembles '
          'each of seven categories. It is NOT a medical device, NOT a diagnosis, and '
          'has not been approved or clinically validated by any regulatory authority. '
          'It does not replace examination, testing, or advice from a qualified '
          'healthcare professional.'
    ),
    (
      '2. No medical advice',
      'Nothing in this app — including model outputs, percentages, urgency labels, or '
          'the AI assistant’s replies — is medical advice. The model can be wrong in '
          'both directions. In particular it correctly flags only about 69% of true '
          'melanomas, so a low cancer score does NOT rule out cancer. Always consult a '
          'dermatologist about any new, changing, or concerning skin spot, regardless '
          'of what Veyrion shows.'
    ),
    (
      '3. Emergencies',
      'Veyrion is not for emergencies. If you have a medical emergency, contact your local '
          'emergency services or a doctor immediately.'
    ),
    (
      '4. AI assistant',
      'The in-app assistant is powered by a third-party large language model. Its '
          'answers are generated automatically, may be inaccurate or incomplete, and '
          'must not be relied upon for medical decisions. Do not share information you '
          'consider sensitive beyond what is needed to use the app.'
    ),
    (
      '5. Images and data',
      'Images you capture are sent to the configured inference server only to produce a '
          'result and are processed for that purpose. Your scan history and chat history '
          'are stored locally on your device and can be deleted by you at any time from '
          'within the app. Do not upload images of other people without their consent.'
    ),
    (
      '6. Acceptable use',
      'You agree to use Veyrion lawfully and only for its intended screening-support and '
          'educational purpose. You will not misrepresent its output as a medical '
          'diagnosis to yourself or others.'
    ),
    (
      '7. No warranty & limitation of liability',
      'Veyrion is provided “as is”, without warranties of any kind. To the maximum extent '
          'permitted by law, the developers and their institution accept no liability '
          'for any loss, harm, or damage arising from use of, or reliance on, this app '
          'or its outputs.'
    ),
    (
      '8. Academic project',
      'Veyrion is a student project developed for educational purposes. Features, models, '
          'and availability may change without notice.'
    ),
    (
      '9. Acceptance',
      'By using Veyrion you acknowledge that you have read, understood, and agree to these '
          'Terms & Conditions and the in-app medical disclaimers.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        automaticallyImplyLeading: !asGate, // gate: no back, must choose
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('Veyrion™ — Terms & Conditions',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Please read carefully before use.',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      for (final (title, body) in _sections) ...[
                        Text(title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(body, style: const TextStyle(height: 1.45)),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
                if (asGate)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onDecision != null
                                ? onDecision!(false)
                                : Navigator.of(context).pop(false),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => onDecision != null
                                ? onDecision!(true)
                                : Navigator.of(context).pop(true),
                            child: const Text('I agree'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
