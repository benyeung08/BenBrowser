import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/models/app_settings.dart';
import '../../state/providers.dart';
import '../browser/navigation.dart';

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
            _SectionTitle(title: '常规'),
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
              items: const ['system', 'desktop', 'mobile', 'custom'],
              labelOf: (id) => switch (id) {
                'custom' => '自定义',
                _ => UserAgentPreset.fromId(id).label,
              },
              onChanged: (id) => ref
                  .read(settingsProvider.notifier)
                  .patch((s) => s.copyWith(userAgentModeId: id)),
            ),
            if (settings.userAgentModeId == 'custom')
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

class _SectionTitle extends StatelessWidget {
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
