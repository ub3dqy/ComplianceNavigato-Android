import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/updates/automatic_updates.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';

final class ComplianceNavigatorApp extends ConsumerWidget {
  const ComplianceNavigatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode =
        ref.watch(themeControllerProvider).value ?? ThemeMode.system;
    return MaterialApp.router(
      title: 'Комплаенс-Навигатор Pilot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(appRouterProvider),
      builder: (_, child) =>
          AutomaticAppUpdates(child: child ?? const SizedBox.shrink()),
    );
  }
}
