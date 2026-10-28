import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/account_service.dart';
import 'state/providers.dart';

Future<void> main() async {
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
}
