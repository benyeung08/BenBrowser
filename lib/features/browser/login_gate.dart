import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../state/providers.dart';
import 'sign_in_form.dart';

/// 登录门：未登录时不展示浏览器，只显示登录界面。
///
/// Android 与 Windows 都会走到这里——书签与设置的云同步挂在账号上，
/// 两端统一成同一套进入方式。
///
/// 文案刻意不写死平台名：同一个组件跑在两个端上，
/// 不能让 Android 用户看到「Windows 版需要登录」这种话。
///
/// **安全网（重要）**：若 Supabase 还没配置（[AccountService.isReady] 为
/// false），此时根本登不进去，绝不能把用户锁死在登录页——会显示配置
/// 引导，并提供「暂不登录，直接使用」的出口。
/// 这条对两个端都一样重要，否则应用会完全打不开。
class LoginGate extends ConsumerWidget {
  const LoginGate({super.key, required this.onSkip});

  /// 跳过登录（仅在云服务未配置时可用）
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(accountServiceProvider).isReady;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '需要先登录才能使用',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (ready)
                    const SignInForm(showSyncNote: true)
                  else ...[
                    const _NotConfiguredNotice(),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: onSkip,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('暂不登录，直接使用'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 未配置 Supabase 时的提示。
///
/// 必须说清楚「现在登不了是谁的问题」——否则用户会以为是应用坏了。
class _NotConfiguredNotice extends StatelessWidget {
  const _NotConfiguredNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 20,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  '登录服务未配置',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '尚未填入 Supabase 的 URL 与 key，所以现在无法登录。'
              '为避免应用完全不可用，可以先跳过登录直接使用；'
              '配置好后再在「设置 → 账号」里登录。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '配置位置：lib/core/constants.dart 的 CloudConfig，'
              '或用 --dart-define 注入。步骤见 README「账号与云同步」。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
