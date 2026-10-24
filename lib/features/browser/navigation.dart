import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/url_utils.dart';
import '../../data/models/browser_tab.dart';
import '../../state/providers.dart';
import '../../state/tabs_controller.dart';

/// 统一入口：把用户输入解析成 Uri，并让当前标签加载
Future<void> navigateTo(WidgetRef ref, BrowserTab tab, String input) async {
  final settings = ref.read(settingsProvider).valueOrNull;
  final uri = UrlUtils.resolve(input, engine: settings?.searchEngine);
  await loadUri(ref, tab, uri);
}

Future<void> loadUri(WidgetRef ref, BrowserTab tab, Uri uri) async {
  final controller = ref.read(webViewRegistryProvider).get(tab.id);
  if (controller == null) {
    // 新标签页还没有 WebView 实例，直接改写状态，由 UI 重建时加载
    ref.read(tabsProvider.notifier).updateTab(
          tab.id,
          (t) => t.copyWith(url: uri.toString(), isLoading: true),
        );
    return;
  }
  await controller.loadUrl(
    urlRequest: URLRequest(url: WebUri(uri.toString())),
  );
}

/// 浏览器动作：后退 / 前进 / 刷新 / 停止 / 回主页
Future<void> performBrowserAction(
  WidgetRef ref,
  BrowserTab tab,
  BrowserAction action,
) async {
  final controller = ref.read(webViewRegistryProvider).get(tab.id);
  if (controller == null) {
    if (action == BrowserAction.home) {
      final home = ref.read(settingsProvider).valueOrNull?.homeUrl;
      if (home != null) await navigateTo(ref, tab, home);
    }
    return;
  }
  switch (action) {
    case BrowserAction.back:
      if (await controller.canGoBack()) await controller.goBack();
      break;
    case BrowserAction.forward:
      if (await controller.canGoForward()) await controller.goForward();
      break;
    case BrowserAction.reload:
      await controller.reload();
      break;
    case BrowserAction.stop:
      await controller.stopLoading();
      break;
    case BrowserAction.home:
      await navigateTo(
        ref,
        tab,
        ref.read(settingsProvider).valueOrNull?.homeUrl ?? 'about:blank',
      );
      break;
  }
}

enum BrowserAction { back, forward, reload, stop, home }

/// 清除浏览数据（缓存 + 本地历史）
Future<void> clearBrowsingData(WidgetRef ref) async {
  final registry = ref.read(webViewRegistryProvider);
  final tabs = ref.read(tabsProvider);
  for (final t in tabs.tabs) {
    final c = registry.get(t.id);
    if (c == null) continue;
    try {
      await c.clearCache();
    } catch (_) {
      // Windows 内核未实现时忽略，仅清理本地数据
    }
  }
  final history = await ref.read(historyRepositoryProvider.future);
  await history.clear();
  ref.invalidate(historyProvider);
}
