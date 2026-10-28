import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_account.dart';
import '../../state/providers.dart';

/// 登录表单：先选渠道（Google / Microsoft 二选一），再点统一的登录按钮。
///
/// 刻意做成单选而不是两个并列按钮——同一时刻只能登录一个账号，
/// 让用户在点之前先确认要用哪个，避免误点到另一个渠道。
///
/// 抽成独立组件是为了让「设置页的账号区」和「Windows 登录门」
/// 共用同一套交互，避免两处行为不一致。
class SignInForm extends ConsumerStatefulWidget {
  const SignInForm({super.key, this.showSyncNote = true});

  /// 登录门里已经单独说明过同步范围时，这里就不再重复
  final bool showSyncNote;

  @override
  ConsumerState<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<SignInForm> {
  AccountProvider _selected = AccountProvider.google;
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await ref.read(accountServiceProvider).signIn(_selected);
      if (!mounted) return;
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('无法启动登录，请检查 Supabase 配置')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '选择登录方式',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        ProviderChoice(
          provider: AccountProvider.google,
          icon: Icons.g_mobiledata,
          selected: _selected == AccountProvider.google,
          onChanged: _busy
              ? null
              : () => setState(() => _selected = AccountProvider.google),
        ),
        const SizedBox(height: 10),
        ProviderChoice(
          provider: AccountProvider.microsoft,
          icon: Icons.window_outlined,
          selected: _selected == AccountProvider.microsoft,
          onChanged: _busy
              ? null
              : () => setState(() => _selected = AccountProvider.microsoft),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _signIn,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_selected.hint),
        ),
        if (widget.showSyncNote) ...[
          const SizedBox(height: 16),
          Text(
            '两种账号二选一，同一时刻只能登录一个；'
            '要换另一种需先退出登录。'
            '登录后书签与设置会在设备间同步；历史记录与标签页不同步。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// 单选卡片：点击整块即可选中
class ProviderChoice extends StatelessWidget {
  const ProviderChoice({
    super.key,
    required this.provider,
    required this.icon,
    required this.selected,
    required this.onChanged,
  });

  final AccountProvider provider;
  final IconData icon;
  final bool selected;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.surface,
      child: RadioListTile<AccountProvider>(
        value: provider,
        groupValue: selected ? provider : null,
        onChanged: onChanged == null ? null : (_) => onChanged!(),
        secondary: Icon(icon, size: 24),
        title: Text(provider.label),
        subtitle: Text(provider.hint),
      ),
    );
  }
}
