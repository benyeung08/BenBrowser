import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/constants.dart';
import 'data/models/app_settings.dart';
import 'features/browser/browser_page.dart';
import 'features/settings/startup_update_check.dart';
import 'state/providers.dart';

class BenBrowserApp extends ConsumerWidget {
  const BenBrowserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final mode = switch (settings?.themeMode ?? ThemeModeSetting.system) {
      ThemeModeSetting.light => ThemeMode.light,
      ThemeModeSetting.dark => ThemeMode.dark,
      ThemeModeSetting.system => ThemeMode.system,
    };

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: const StartupUpdateCheck(child: BrowserPage()),
    );
  }
}
