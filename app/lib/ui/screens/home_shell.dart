import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../state/app_controller.dart';
import '../../state/scan_controller.dart';
import '../widgets/brand.dart';
import '../widgets/glass.dart';
import 'about_screen.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  List<_Dest> get _destinations => [
        _Dest('nav.scan'.tr(), Icons.center_focus_strong_outlined,
            Icons.center_focus_strong),
        _Dest('nav.history'.tr(), Icons.history_outlined, Icons.history),
        _Dest('nav.learn'.tr(), Icons.menu_book_outlined, Icons.menu_book),
        _Dest('nav.settings'.tr(), Icons.settings_outlined, Icons.settings),
      ];

  Widget _page(int i) {
    switch (i) {
      case 0:
        return const ScanScreen();
      case 1:
        return const HistoryScreen();
      case 2:
        return const AboutScreen();
      default:
        return const SettingsScreen(embedded: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 800;
    final compact = width < 480; // hide non-essential app-bar items when tight

    return ChangeNotifierProvider(
      create: (_) => ScanController(app),
      child: Scaffold(
        extendBody: true, // let content scroll behind the frosted glass nav
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConfig.appName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    const Text(
                      '™',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0E7C86)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (!compact) _RoleChip(role: app.role, name: app.displayName),
            if (app.mockMode)
              compact
                  ? IconButton(
                      tooltip: 'Mock mode — no model weights loaded',
                      icon: Icon(Icons.science_outlined,
                          color: Theme.of(context).colorScheme.error),
                      onPressed: () {},
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Tooltip(
                        message: 'appbar.mockTooltip'.tr(),
                        child: Chip(
                          label: Text('appbar.mockShort'.tr()),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              Theme.of(context).colorScheme.errorContainer,
                        ),
                      ),
                    ),
            IconButton(
              tooltip: 'appbar.assistant'.tr(),
              icon: const Icon(Icons.forum_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              ),
            ),
            IconButton(
              tooltip: 'appbar.signOut'.tr(),
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmLogout(context, app),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    labelType: NavigationRailLabelType.all,
                    destinations: _destinations
                        .map((d) => NavigationRailDestination(
                              icon: Icon(d.icon),
                              selectedIcon: Icon(d.selected),
                              label: Text(d.label),
                            ))
                        .toList(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: KeyedSubtree(
                        key: ValueKey(_index),
                        child: _page(_index),
                      ),
                    ),
                  ),
                ],
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: _page(_index),
                ),
              ),
        bottomNavigationBar: wide
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: GlassPanel(
                  radius: 28,
                  child: NavigationBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    surfaceTintColor: Colors.transparent,
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    destinations: _destinations
                        .map((d) => NavigationDestination(
                              icon: Icon(d.icon),
                              selectedIcon: Icon(d.selected),
                              label: d.label,
                            ))
                        .toList(),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AppController app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('logout.title'.tr()),
        content: Text('logout.body'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('logout.confirm'.tr())),
        ],
      ),
    );
    if (ok == true) await app.logout();
  }
}

class _Dest {
  final String label;
  final IconData icon;
  final IconData selected;
  const _Dest(this.label, this.icon, this.selected);
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role, required this.name});
  final String role;
  final String name;

  @override
  Widget build(BuildContext context) {
    final isClinic = role == 'clinic';
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Chip(
        avatar: Icon(
            isClinic ? Icons.local_hospital_outlined : Icons.person_outline,
            size: 16,
            color: c.primary),
        label: Text(isClinic ? 'role.clinic'.tr() : 'role.patient'.tr()),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
