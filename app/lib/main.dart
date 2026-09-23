import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'services/storage.dart';
import 'state/app_controller.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/terms_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('bn')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      child: const DarmApp(),
    ),
  );
}

class DarmApp extends StatelessWidget {
  const DarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppController(Storage())..bootstrap(),
      child: Consumer<AppController>(
        builder: (context, app, _) => MaterialApp(
          title: '${AppConfig.appName} — ${AppConfig.appTagline}',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: app.themeMode,
          scrollBehavior: const SmoothScrollBehavior(),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const _Root(),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    switch (app.status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        // First-run: require accepting the Terms before entering the app.
        if (!app.termsAccepted) {
          return TermsScreen(
            asGate: true,
            onDecision: (accepted) {
              if (accepted) {
                app.acceptTerms();
              } else {
                app.logout();
              }
            },
          );
        }
        return const HomeShell();
    }
  }
}
