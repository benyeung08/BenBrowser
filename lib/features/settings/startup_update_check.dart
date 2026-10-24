import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/release_info.dart';
import '../../state/providers.dart';
import 'update_dialog.dart';

/// 启动后延迟检查一次更新，有新版才弹窗，避免打断正常使用。
/// 包在 home 外层，这样能拿到 MaterialApp 内的 context 来弹对话框。
class StartupUpdateCheck extends ConsumerStatefulWidget {
  const StartupUpdateCheck({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StartupUpdateCheck> createState() =>
      _StartupUpdateCheckState();
}

class _StartupUpdateCheckState extends ConsumerState<StartupUpdateCheck> {
  static const Duration _delay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _scheduleCheck();
  }

  Future<void> _scheduleCheck() async {
    await Future<void>.delayed(_delay);
    if (!mounted) return;

    final settings = ref.read(settingsProvider).valueOrNull;
    if (settings == null || !settings.checkUpdateOnLaunch) return;

    final outcome = await ref
        .read(updateServiceProvider)
        .check(settings.repoSlug);
    if (!mounted) return;

    final release = outcome.release;
    if (!outcome.hasUpdate || release == null) return;

    await showDialog<void>(
      context: context,
      builder: (_) => UpdateDialog(
        release: release,
        currentVersion: outcome.currentVersion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
