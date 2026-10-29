import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_theme.dart';
import 'core/constants.dart';
import 'core/platform_info.dart';
import 'data/models/app_settings.dart';
import 'features/browser/browser_page.dart';
import 'features/settings/login_gate.dart';
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
      home: StartupUpdateCheck(child: _buildHome(ref)),
    );
  }

  /// 决定首屏是浏览器还是登录门。
  ///
  /// 放行条件（满足任一即进浏览器）：
  /// - 当前平台不要求登录（目前 Android / Windows 都要求，只有未知
  ///   平台如 linux 不要求）
  /// - 已登录
  /// - 云服务没配置好，且用户已选「暂不登录」——这时不放行会把人锁死
  Widget _buildHome(WidgetRef ref) {
    if (!requireLoginToBrowse) return const BrowserPage();

    final account = ref.watch(accountProvider);
    if (account != null) return const BrowserPage();

    final ready = ref.watch(accountServiceProvider).isReady;
    final skipped = ref.watch(loginSkippedProvider);
    if (!ready && skipped) return const BrowserPage();

    return LoginGate(
      onSkip: () => ref.read(loginSkippedProvider.notifier).state = true,
    );
  }
}
