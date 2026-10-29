import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/error_reporting.dart';
import 'services/account_service.dart';
import 'state/providers.dart';

Future<void> main() async {
  // 先装好全局兜底：没有它的话，Flutter 框架层的异常（布局越界、
  // 插件抛错等）在 release 包里只会表现为白屏或静默无响应，
  // 既没有日志也没有任何提示，极难排查。
  await ErrorReporting.install();

  // runApp 之前的异常（初始化阶段）由上面的 runZonedGuarded 之外的
  // PlatformDispatcher 兜底，这里再包一层 zone 覆盖整段启动过程
  await ErrorReporting.guard(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 未配置 Supabase 时 initialize() 会直接返回，不联网也不抛异常
    final accountService = AccountService();
    await accountService.initialize();

    runApp(
      ProviderScope(
        overrides: [
          accountServiceProvider.overrideWithValue(accountService),
        ],
        child: const BenBrowserApp(),
      ),
    );
  });
}
