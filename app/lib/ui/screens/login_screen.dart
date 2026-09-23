import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../state/app_controller.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import 'settings_screen.dart';
import 'terms_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await context
        .read<AppController>()
        .login(_user.text.trim(), _pass.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  void _fill(String u, String p) {
    _user.text = u;
    _pass.text = p;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    // Veyrion Trademark Header above Login Page
                    Center(
                      child: GlassPanel(
                        radius: 24,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        blur: 20,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const BrandMark(size: 80),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppConfig.appName,
                                  style:
                                      theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, left: 2),
                                  child: Text(
                                    '™',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppConfig.appTagline,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Backend status
                    _BackendStatus(app: app),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _user,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'login.username'.tr(),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'login.enterUsername'.tr()
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _pass,
                      obscureText: _obscure,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'login.password'.tr(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'login.enterPassword'.tr()
                          : null,
                    ),
                    const SizedBox(height: 18),

                    if (_error != null) ...[
                      Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                    ],

                    FilledButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login),
                      label: Text(_loading ? 'Signing in…' : 'Sign in'),
                    ),
                    const SizedBox(height: 20),

                    // Role explainer + demo creds
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.badge_outlined,
                                    size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Two roles — same full results',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Patients and clinics both see every number. The patient view '
                              'adds plain-language guidance so results are clear without alarm; '
                              'the clinic view adds clinical caveats and record fields.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const Divider(height: 22),
                            _DemoRow(
                              label: 'Patient',
                              creds: 'patient / patient123',
                              onUse: () => _fill('patient', 'patient123'),
                            ),
                            const SizedBox(height: 8),
                            _DemoRow(
                              label: 'Clinic',
                              creds: 'clinic / clinic123',
                              onUse: () => _fill('clinic', 'clinic123'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const DisclaimerBanner(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const TermsScreen()),
                          ),
                          icon:
                              const Icon(Icons.description_outlined, size: 18),
                          label: const Text('Terms & Conditions'),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          ),
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('Server settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackendStatus extends StatelessWidget {
  const _BackendStatus({required this.app});
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final online = app.backendOnline;
    final color = online
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            online
                ? 'Server online${app.mockMode ? ' · mock mode (no weights loaded)' : ''}'
                : 'Server offline — check Server settings',
            style:
                Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _DemoRow extends StatelessWidget {
  const _DemoRow(
      {required this.label, required this.creds, required this.onUse});
  final String label;
  final String creds;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Pill(label,
            icon: Icons.circle, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(creds, style: const TextStyle(fontFamily: 'monospace'))),
        TextButton(onPressed: onUse, child: const Text('Use')),
      ],
    );
  }
}
