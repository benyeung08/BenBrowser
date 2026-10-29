import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_settings.dart';
import '../../data/models/sync_snapshot.dart';
import '../../data/models/user_account.dart';
import '../../state/providers.dart';
import 'sign_in_form.dart';

/// 账号与云同步
///
/// 三种状态：
/// 1. 未配置 Supabase → 显示配置引导，其余功能不受影响
/// 2. 已配置未登录 → Google / Microsoft 登录按钮
/// 3. 已登录 → 账号信息 + 立即同步 + 登出
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final serviceReady = ref.watch(accountServiceProvider).isReady;

    return Scaffold(
      appBar: AppBar(title: const Text('账号与同步')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          if (!serviceReady) ...[
            const _SetupGuide(),
          ] else if (account == null) ...[
            const SignInForm(),
          ] else ...[
            _ProfileCard(account: account),
            _SyncSection(account: account),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 未配置时的引导：告诉用户要填什么、去哪里填
class _SetupGuide extends StatelessWidget {
  const _SetupGuide();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_off_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('云端账号未启用', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '登录与同步需要 Supabase 项目。填入以下两项后重新构建即可启用：',
              ),
              const SizedBox(height: 12),
              const _KeyValue(
                label: 'Supabase URL',
                value: 'https://xxx.supabase.co',
              ),
              const _KeyValue(
                label: 'Publishable key',
                value: 'eyJhbGci...',
              ),
              const SizedBox(height: 12),
              const Text(
                '位置：lib/core/constants.dart 的 CloudConfig，'
                '或构建时用 --dart-define 注入。'
                '完整步骤见 README「账号与云同步」。',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 已登录：头像、名称、邮箱
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.account});

  final UserAccount account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage:
                    account.avatarUrl == null ? null : NetworkImage(account.avatarUrl!),
                child: account.avatarUrl == null
                    ? Text(
                        account.initial.toUpperCase(),
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.title,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (account.email != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        account.email!,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'via ${account.provider.label}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 同步操作区
class _SyncSection extends ConsumerStatefulWidget {
  const _SyncSection({required this.account});

  final UserAccount account;

  @override
  ConsumerState<_SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends ConsumerState<_SyncSection> {
  bool _busy = false;

  Future<void> _sync() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final bookmarks = await ref.read(bookmarksProvider.future);
      if (!mounted) return;
      final settings =
          ref.read(settingsProvider).valueOrNull ?? const AppSettings();
      final local = SyncSnapshot(
        bookmarks: bookmarks,
        settings: settings,
        updatedAt: DateTime.now(),
      );

      final sync = ref.read(syncServiceProvider);
      final remote = await sync.pull();
      final merged = remote == null ? local : local.mergeWith(remote);

      // 合并结果既写回本地，也推回云端 —— 双向收敛
      await _applyLocally(merged);
      if (!mounted) return;
      final ok = await sync.push(merged);

      if (!mounted) return;
      ref.read(lastSyncAtProvider.notifier).state = DateTime.now();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '已同步 ${merged.bookmarks.length} 个书签'
                : '本地已更新，但上传失败（稍后重试）',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('同步失败：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 把合并后的结果落回本地仓库
  ///
  /// 书签可能有成百上千条，逐条 await 期间用户完全可能退出本页，
  /// 所以每步都确认 mounted —— 否则 ref 会抛 StateError。
  Future<void> _applyLocally(SyncSnapshot snapshot) async {
    final bookmarkRepo = await ref.read(bookmarkRepositoryProvider.future);
    if (!mounted) return;
    for (final b in snapshot.bookmarks) {
      await bookmarkRepo.put(b);
      if (!mounted) return;
    }
    await ref.read(settingsProvider.notifier).save(snapshot.settings);
    if (!mounted) return;
    ref.invalidate(bookmarksProvider);
  }

  Future<void> _signOut() async {
    await ref.read(accountServiceProvider).signOut();
    if (!mounted) return;
    ref.read(lastSyncAtProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final lastSync = ref.watch(lastSyncAtProvider);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('立即同步'),
          subtitle: Text(
            lastSync == null
                ? '把书签与设置合并到云端'
                : '上次同步：${_format(lastSync)}',
          ),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _busy ? null : _sync,
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('退出登录'),
          subtitle: Text(
            '可改用 ${widget.account.provider == AccountProvider.google ? 'Microsoft' : 'Google'} 账号重新登录；本地数据会保留',
          ),
          onTap: _signOut,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '同步范围：书签（按 id 取并集）与设置。'
            '历史记录、标签页、下载不同步。'
            '删除书签不会跨设备传播。',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  String _format(DateTime time) {
    final t = time.toLocal();
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '${t.month}/${t.day} $h:$m';
  }
}

/// 供设置页复用：一行入口，未配置时显示提示
class AccountTile extends ConsumerWidget {
  const AccountTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(accountServiceProvider).isReady;
    final account = ref.watch(accountProvider);

    final subtitle = !ready
        ? '未配置，点此查看启用步骤'
        : (account == null ? '未登录' : account.title);

    return ListTile(
      leading: const Icon(Icons.account_circle_outlined),
      title: const Text('账号与同步'),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AccountPage()),
      ),
    );
  }
}
