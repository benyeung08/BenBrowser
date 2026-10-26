import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/platform_info.dart';
import '../../core/url_utils.dart';
import '../../data/models/browser_tab.dart';
// ★ bookmarksProvider / bookmarkRepositoryProvider / tabsProvider 定义在这里，
//   漏掉这两行就会报 undefined_identifier
import '../../state/providers.dart';
import '../../state/tabs_controller.dart';
import '../bookmarks/bookmarks_page.dart';
import '../downloads/downloads_page.dart';
import '../history/history_page.dart';
import '../settings/settings_page.dart';
import 'navigation.dart';

/// 顶部工具栏：前进/后退/刷新 + 地址栏 + 书签 + 主菜单
class BrowserToolbar extends ConsumerStatefulWidget {
  const BrowserToolbar({super.key, required this.tab});

  final BrowserTab tab;

  @override
  ConsumerState<BrowserToolbar> createState() => _BrowserToolbarState();
}

class _BrowserToolbarState extends ConsumerState<BrowserToolbar> {
  final _editor = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _editor.text = _display(widget.tab.url);
    _focus.addListener(() {
      if (_editing != _focus.hasFocus) {
        setState(() => _editing = _focus.hasFocus);
      }
    });
  }

  @override
  void didUpdateWidget(covariant BrowserToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing) {
      final next = _display(widget.tab.url);
      if (_editor.text != next) _editor.text = next;
    }
  }

  @override
  void dispose() {
    _editor.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _display(String url) =>
      url == AppConstants.newTabUrl || url.isEmpty ? '' : url;

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final isBookmarked = ref.watch(bookmarksProvider).maybeWhen(
          data: (list) => list.any((b) => b.url == tab.url),
          orElse: () => false,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
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
            tooltip: tab.isLoading ? '停止' : '刷新',
            icon: Icon(tab.isLoading ? Icons.close : Icons.refresh),
            onPressed: () => performBrowserAction(
              ref,
              tab,
              tab.isLoading ? BrowserAction.stop : BrowserAction.reload,
            ),
          ),
          if (!useCompactLayout)
            IconButton(
              tooltip: '主页',
              icon: const Icon(Icons.home_outlined),
              onPressed: () =>
                  performBrowserAction(ref, tab, BrowserAction.home),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _editor,
              focusNode: _focus,
              textInputAction: TextInputAction.go,
              onSubmitted: (value) {
                navigateTo(ref, tab, value);
                _focus.unfocus();
              },
              decoration: InputDecoration(
                hintText: '搜索或输入网址',
                prefixIcon: Icon(
                  tab.incognito
                      ? Icons.visibility_off
                      : (UrlUtils.isSecure(tab.url)
                          ? Icons.lock_outline
                          : Icons.language),
                  size: 18,
                ),
                suffixIcon: _editing && _editor.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _editor.clear()),
                      )
                    : null,
              ),
            ),
          ),
          IconButton(
            tooltip: isBookmarked ? '取消收藏' : '加入书签',
            icon: Icon(isBookmarked ? Icons.star : Icons.star_border),
            onPressed: () => _toggleBookmark(tab, isBookmarked),
          ),
          _MainMenu(tab: tab),
        ],
      ),
    );
  }

  Future<void> _toggleBookmark(BrowserTab tab, bool exists) async {
    if (tab.url.isEmpty || tab.url == AppConstants.newTabUrl) return;
    final repo = await ref.read(bookmarkRepositoryProvider.future);
    if (exists) {
      final list = await repo.all();
      final targets = list.where((b) => b.url == tab.url).toList();
      for (final t in targets) {
        await repo.remove(t.id);
      }
    } else {
      await repo.add(title: tab.displayTitle, url: tab.url);
    }
    ref.invalidate(bookmarksProvider);
  }
}

/// 主菜单
class _MainMenu extends ConsumerWidget {
  const _MainMenu({required this.tab});

  final BrowserTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: '菜单',
      onSelected: (value) async {
        switch (value) {
          case 'new_tab':
            ref.read(tabsProvider.notifier).openTab();
            break;
          case 'new_incognito':
            ref.read(tabsProvider.notifier).openTab(incognito: true);
            break;
          case 'bookmarks':
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BookmarksPage()),
            );
            break;
          case 'history':
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
            );
            break;
          case 'downloads':
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const DownloadsPage()),
            );
            break;
          case 'settings':
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            );
            break;
          case 'clear':
            await clearBrowsingData(ref);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已清除缓存与历史记录')),
              );
            }
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(value: 'new_tab', child: Text('新标签页')),
        PopupMenuItem<String>(value: 'new_incognito', child: Text('无痕标签页')),
        PopupMenuDivider(),
        PopupMenuItem<String>(value: 'bookmarks', child: Text('书签')),
        PopupMenuItem<String>(value: 'history', child: Text('历史记录')),
        PopupMenuItem<String>(value: 'downloads', child: Text('下载')),
        PopupMenuDivider(),
        PopupMenuItem<String>(value: 'clear', child: Text('清除浏览数据')),
        PopupMenuItem<String>(value: 'settings', child: Text('设置')),
      ],
    );
  }
}
