import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/platform_info.dart';
import '../../data/models/browser_tab.dart';
import '../../state/providers.dart';
import '../../state/tabs_controller.dart';
import '../new_tab/new_tab_page.dart';
import 'browser_toolbar.dart';
import 'navigation.dart';
import 'tab_strip.dart';
import 'web_view_surface.dart';

/// 浏览器主页面：标签条 + 工具栏 + WebView 栈
class BrowserPage extends ConsumerWidget {
  const BrowserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(tabsProvider);

    // 设置加载完成后，确保至少有一个标签
    ref.listen(settingsProvider, (previous, next) {
      next.whenData((_) {
        ref.read(tabsProvider.notifier).ensureInitialTab();
      });
    });

    final active = tabs.activeTab;

    // Android 17：大屏上系统不再理会方向/尺寸限制，布局只能按窗口宽度定。
    // 窄窗口（手机竖屏、分屏小窗）用底部工具栏更好按。
    final compact = isCompactWindow(MediaQuery.sizeOf(context).shortestSide);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (active != null) const TabStrip(),
            if (active != null) BrowserToolbar(tab: active),
            if (active != null) _ProgressBar(tab: active),
            Expanded(child: _buildBody(ref, tabs)),
            if (active != null && compact) _BottomBar(tab: active),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(WidgetRef ref, TabsState tabs) {
    if (tabs.isEmpty) return const _EmptyView();
    return IndexedStack(
      index: tabs.safeIndex,
      children: [
        for (final tab in tabs.tabs)
          KeyedSubtree(
            key: ValueKey<String>(tab.id),
            child: _TabBody(tab: tab),
          ),
      ],
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.tab});

  final BrowserTab tab;

  @override
  Widget build(BuildContext context) {
    final isBlank =
        tab.url.isEmpty || tab.url == AppConstants.newTabUrl;
    return isBlank
        ? NewTabPage(tab: tab)
        : WebViewSurface(key: ValueKey<String>(tab.id), tab: tab);
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.tab});

  final BrowserTab tab;

  @override
  Widget build(BuildContext context) {
    final loading = tab.isLoading || (tab.progress > 0 && tab.progress < 100);
    return SizedBox(
      height: 2,
      child: loading
          ? LinearProgressIndicator(
              value: tab.progress > 0 ? tab.progress / 100 : null,
              minHeight: 2,
            )
          : null,
    );
  }
}

class _EmptyView extends ConsumerWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tab_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('所有标签已关闭'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.read(tabsProvider.notifier).openTab(
                  url: ref.read(settingsProvider).valueOrNull?.homeUrl ??
                      AppConstants.defaultHome,
                ),
            child: const Text('新建标签页'),
          ),
        ],
      ),
    );
  }
}

/// 移动端底部操作栏，方便单手操作
class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.tab});

  final BrowserTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(tabsProvider);
    // Theme.dividerColor 已废弃（deprecated_member_use），改用 dividerTheme
    final dividerColor = Theme.of(context).dividerTheme.color ??
        Theme.of(context).colorScheme.outlineVariant;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            tooltip: '后退',
            icon: const Icon(Icons.arrow_back),
            onPressed: tab.canGoBack
                ? () => performBrowserAction(ref, tab, BrowserAction.back)
                : null,
          ),
          IconButton(
            tooltip: '前进',
            icon: const Icon(Icons.arrow_forward),
            onPressed: tab.canGoForward
                ? () => performBrowserAction(ref, tab, BrowserAction.forward)
                : null,
          ),
          IconButton(
            tooltip: '主页',
            icon: const Icon(Icons.home_outlined),
            onPressed: () =>
                performBrowserAction(ref, tab, BrowserAction.home),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: '标签',
                icon: const Icon(Icons.tab),
                onPressed: () => ref.read(tabsProvider.notifier).openTab(),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: CircleAvatar(
                  radius: 8,
                  child: Text(
                    '${tabs.tabs.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
