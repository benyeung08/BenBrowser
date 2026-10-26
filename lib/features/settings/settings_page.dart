import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/release_info.dart';
import '../../state/providers.dart';
import '../browser/navigation.dart';
import '../downloads/downloads_page.dart';
import 'update_dialog.dart';

/// 设置页
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('设置加载失败：$e')),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const _SectionTitle(title: '常规'),
            _TextTile(
              label: '主页',
              value: settings.homeUrl,
              onSubmitted: (v) => ref
                  .read(settingsProvider.notifier)
                  .patch((s) => s.copyWith(homeUrl: v.trim())),
            ),
            _DropdownTile<SearchEngine>(
              label: '搜索引擎',
              value: settings.searchEngine,
              items: SearchEngine.all,
              labelOf: (e) => e.label,
              onChanged: (e) => ref
                  .read(settingsProvider.notifier)
                  .patch((s) => s.copyWith(searchEngineId: e.id)),
            ),
            _DropdownTile<ThemeModeSetting>(
              label: '外观',
              value: settings.themeMode,
              items: ThemeModeSetting.values,
              labelOf: (e) => switch (e) {
                ThemeModeSetting.system => '跟随系统',
                ThemeModeSetting.light => '浅色',
                ThemeModeSetting.dark => '深色',
              },
              onChanged: (e) => ref
                  .read(settingsProvider.notifier)
                  .patch((s) => s.copyWith(themeMode: e)),
            ),
            const _SectionTitle(title: '隐私与站点'),
            _DropdownTile<String>(
              label: 'User-Agent',
              value: settings.userAgentModeId,
              items: const [
                UserAgentPreset.systemId,
                'desktop',
                'mobile',
                UserAgentPreset.customId,
              ],
              labelOf: (id) => switch (id) {
                UserAgentPreset.customId => '自定义',
                _ => UserAgentPreset.fromId(id).label,
              },
              onChanged: (id) => ref
                  .read(settingsProvider.notifier)
                  .patch((s) => s.copyWith(userAgentModeId: id)),
            ),
            if (settings.userAgentModeId == UserAgentPreset.customId)
              _TextTile(
                label: '自定义 UA',
                value: settings.customUserAgent,
                hint: '留空则跟随系统',
                onSubmitted: (v) => ref
                    .read(settingsProvider.notifier)
                    .patch((s) => s.copyWith(customUserAgent: v)),
              ),
            SwitchListTile(
              title: const Text('启用 JavaScript'),
              subtitle: const Text('关闭后部分站点不可用'),
              value: settings.javaScriptEnabled,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .patch((s) => s.copyWith(javaScriptEnabled: v)),
            ),
            SwitchListTile(
              title: const Text('新标签默认无痕'),
              subtitle: const Text('无痕标签不写入历史记录与缓存'),
              value: settings.incognitoByDefault,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .patch((s) => s.copyWith(incognitoByDefault: v)),
            ),
            const _SectionTitle(title: '数据'),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('清除浏览数据'),
              subtitle: const Text('清除缓存与历史记录'),
              onTap: () async {
                await clearBrowsingData(ref);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已清除')),
                  );
                }
              },
            ),
            const _SectionTitle(title: '更新'),
            const _UpdateTile(),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('查看下载'),
              subtitle: const Text('更新包与网页下载都在这里，Android 可直接安装'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DownloadsPage(),
                ),
              ),
            ),
            _TextTile(
              label: 'GitHub 仓库',
              value: settings.repoSlug,
              hint: 'owner/repo，用于检查更新',
              onSubmitted: (v) => ref
                  .read(settingsProvider.notifier)
                  .patch((s) => s.copyWith(repoSlug: v.trim())),
            ),
            SwitchListTile(
              title: const Text('启动时自动检查更新'),
              subtitle: const Text('有新版时弹窗提示，需你确认后才下载'),
              value: settings.checkUpdateOnLaunch,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .patch((s) => s.copyWith(checkUpdateOnLaunch: v)),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '${AppConstants.appName} · 设置会在新建标签页后对新页面生效',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「检查更新」入口：显示当前版本，点击后查询 GitHub 最新 Release。
/// 有新版本时弹出更新对话框；Android 上点「后台下载」会交给浏览器的
/// 下载管理器处理，进度可在「下载」页看到。
class _UpdateTile extends ConsumerStatefulWidget {
  const _UpdateTile();

  @override
  ConsumerState<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends ConsumerState<_UpdateTile> {
  bool _checking = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    final v = await ref.read(updateServiceProvider).currentVersion();
    if (!mounted) return;
    setState(() => _version = v);
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);

    final settings = ref.read(settingsProvider).valueOrNull;
    final outcome = await ref.read(updateServiceProvider).check(
          settings?.repoSlug ?? AppConstants.defaultRepoSlug,
        );

    if (!mounted) return;
    setState(() => _checking = false);

    final release = outcome.release;
    if (outcome.hasUpdate && release != null) {
      await showDialog<void>(
        context: context,
        builder: (_) => UpdateDialog(
          release: release,
          currentVersion: outcome.currentVersion,
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_message(outcome))),
    );
  }

  String _message(UpdateCheckOutcome outcome) => switch (outcome.result) {
        UpdateCheckResult.upToDate =>
          '已是最新版本（${outcome.currentVersion}）',
        UpdateCheckResult.noRelease =>
          outcome.message ?? '该仓库还没有发布 Release',
        UpdateCheckResult.failed => outcome.message ?? '检查更新失败，请检查网络',
        UpdateCheckResult.available => '发现新版本',
      };

  @override
  Widget build(BuildContext context) {
    final versionText = _version.isEmpty ? '读取中…' : 'v$_version';
    return ListTile(
      leading: _checking
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.system_update_alt),
      title: const Text('检查更新'),
      subtitle: Text('当前版本 $versionText'),
      trailing: _checking ? null : const Icon(Icons.chevron_right),
      enabled: !_checking,
      onTap: _check,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  // 不要加 super.key：这个私有 Widget 在文件内从不传 key，
  // 会被判 unused_element_parameter（warning）
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}

class _TextTile extends StatefulWidget {
  const _TextTile({
    required this.label,
    required this.value,
    this.hint,
    required this.onSubmitted,
  });

  final String label;
  final String value;
  final String? hint;
  final ValueChanged<String> onSubmitted;

  @override
  State<_TextTile> createState() => _TextTileState();
}

class _TextTileState extends State<_TextTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(widget.label),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: widget.hint ?? widget.label),
            onSubmitted: widget.onSubmitted,
          ),
        ),
      );
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(label),
        trailing: DropdownButton<T>(
          value: value,
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(labelOf(item)),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
}
