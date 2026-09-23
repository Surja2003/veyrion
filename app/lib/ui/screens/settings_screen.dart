import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../state/app_controller.dart';
import '../widgets/common.dart';
import 'terms_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  /// When true, rendered inside the HomeShell tab (no Scaffold/AppBar).
  final bool embedded;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: context.read<AppController>().baseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _checking = true);
    await context.read<AppController>().setBaseUrl(_url.text.trim());
    if (!mounted) return;
    setState(() => _checking = false);
    final online = context.read<AppController>().backendOnline;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          online ? 'Connected to server' : 'Saved, but server not reachable'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.embedded)
              Text('settings.title'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            if (widget.embedded) const SizedBox(height: 16),

            // Language selector — live in-app switch (English / Hindi / Bengali).
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.translate, size: 20),
                        const SizedBox(width: 8),
                        SectionHeader('settings.language'.tr()),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        _LangChip(
                            code: 'en', label: 'settings.languageEnglish'.tr()),
                        _LangChip(
                            code: 'hi', label: 'settings.languageHindi'.tr()),
                        _LangChip(
                            code: 'bn', label: 'settings.languageBengali'.tr()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Appearance (theme) selector.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.contrast, size: 20),
                        const SizedBox(width: 8),
                        SectionHeader('settings.appearance'.tr()),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        _ThemeChip(
                            mode: ThemeMode.system,
                            label: 'settings.themeSystem'.tr(),
                            icon: Icons.brightness_auto),
                        _ThemeChip(
                            mode: ThemeMode.light,
                            label: 'settings.themeLight'.tr(),
                            icon: Icons.light_mode),
                        _ThemeChip(
                            mode: ThemeMode.dark,
                            label: 'settings.themeDark'.tr(),
                            icon: Icons.dark_mode),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                            child: SectionHeader('Inference server')),
                        _StatusDot(online: app.backendOnline),
                      ],
                    ),
                    TextField(
                      controller: _url,
                      decoration: const InputDecoration(
                        labelText: 'API base URL',
                        hintText: 'https://your-space.hf.space',
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      app.backendOnline
                          ? 'Online${app.mockMode ? ' · mock mode (no weights loaded)' : ' · weights loaded'}'
                          : 'Not reachable. Start the backend, or set the correct URL.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: app.backendOnline
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _checking ? null : _save,
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save & test connection'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Signed in as'),
                    subtitle: Text(
                        '${app.displayName} · ${app.isClinic ? 'Clinic' : 'Patient'}'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms & Conditions'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TermsScreen()),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    onTap: () => app.logout(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader('About'),
                    Text('${AppConfig.appName} — ${AppConfig.appTagline}'),
                    const Text('Version 1.0.0'),
                    const SizedBox(height: 8),
                    Text(
                      'A decision-support client for the multi-backbone skin-lesion fusion model. '
                      'Not a medical device.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const TermsScreen()),
                        ),
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: Text('settings.terms'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const DisclaimerBanner(),
          ],
        ),
      ),
    );

    if (widget.embedded) return SafeArea(child: body);
    return Scaffold(
        appBar: AppBar(title: const Text('Server settings')), body: body);
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({required this.code, required this.label});
  final String code;
  final String label;
  @override
  Widget build(BuildContext context) {
    final selected = context.locale.languageCode == code;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => context.setLocale(Locale(code)),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip(
      {required this.mode, required this.label, required this.icon});
  final ThemeMode mode;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final selected = app.themeMode == mode;
    return ChoiceChip(
      avatar: Icon(icon,
          size: 18,
          color: selected
              ? Theme.of(context).colorScheme.onSecondaryContainer
              : null),
      label: Text(label),
      selected: selected,
      onSelected: (_) => context.read<AppController>().setThemeMode(mode),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});
  final bool online;
  @override
  Widget build(BuildContext context) {
    final color = online
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(online ? 'Online' : 'Offline',
            style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
