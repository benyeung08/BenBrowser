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
        // Flutter 3.32 起 Radio/RadioListTile 的 groupValue / onChanged 已弃用，
        // 改为由 RadioGroup 祖先统一管理。附带好处：整组变成一个 tab 停靠点、
        // 方向键可在选项间移动，无障碍语义也对得上。
        //
        // 泛型必须显式写：RadioGroup 按**精确类型**匹配内部的 Radio，
        // 靠推断很容易匹配不上，表现是「点了没反应」而不是报错，极难排查。
        RadioGroup<AccountProvider>(
          groupValue: _selected,
          // onChanged 是**必填且不可为 null** 的（类型 ValueChanged<T?>），
          // 所以不能写 `_busy ? null : fn` —— 那会得到可空函数类型，
          // 报 argument_type_not_assignable。
          // 禁用改用内部 Radio 的 `enabled: false`（见 ProviderChoice）。
          onChanged: (AccountProvider? value) {
            if (_busy || value == null) return;
            setState(() => _selected = value);
          },
          child: Column(
            children: [
              ProviderChoice(
                provider: AccountProvider.google,
                icon: Icons.g_mobiledata,
                selected: _selected == AccountProvider.google,
                enabled: !_busy,
              ),
              const SizedBox(height: 10),
              ProviderChoice(
                provider: AccountProvider.microsoft,
                icon: Icons.window_outlined,
                selected: _selected == AccountProvider.microsoft,
                enabled: !_busy,
              ),
            ],
          ),
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
    this.enabled = true,
  });

  final AccountProvider provider;
  final IconData icon;
  final bool selected;

  /// 登录进行中禁用。旧的 `onChanged: null` 写法在新 API 下不再表达禁用，
  /// 必须显式用 `enabled: false`。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.surface,
      child: RadioListTile<AccountProvider>(
        // groupValue / onChanged 由外层 RadioGroup 提供，这里只声明 value
        value: provider,
        enabled: enabled,
        secondary: Icon(icon, size: 24),
        title: Text(provider.label),
        subtitle: Text(provider.hint),
      ),
    );
  }
}
