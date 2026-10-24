import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/url_utils.dart';
import '../../data/models/browser_tab.dart';
import '../../state/downloads_controller.dart';
import '../../state/providers.dart';
import '../../state/tabs_controller.dart';

/// 单个标签页的 WebView 载体。
/// Android → 系统 WebView；Windows → WebView2；macOS → WKWebView。
/// 三端共用同一份 Dart 代码，仅由插件在内部切换内核。
class WebViewSurface extends ConsumerStatefulWidget {
  const WebViewSurface({super.key, required this.tab});

  final BrowserTab tab;

  @override
  ConsumerState<WebViewSurface> createState() => _WebViewSurfaceState();
}

class _WebViewSurfaceState extends ConsumerState<WebViewSurface> {
  InAppWebViewController? _controller;
  late final WebViewRegistry _registry;

  BrowserTab get tab => widget.tab;

  @override
  void initState() {
    super.initState();
    _registry = ref.read(webViewRegistryProvider);
  }

  @override
  void dispose() {
    _registry.remove(tab.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(tab.url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: settings?.javaScriptEnabled ?? true,
        userAgent: settings?.effectiveUserAgent,
        incognito: tab.incognito,
        cacheEnabled: !tab.incognito,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        ref.read(webViewRegistryProvider).register(tab.id, controller);
      },
      onLoadStart: (controller, url) {
        _update(url: url?.toString(), isLoading: true, progress: 0);
      },
      onLoadStop: (controller, url) async {
        _update(url: url?.toString(), isLoading: false, progress: 100);
        await _syncNavState(controller);
        await _recordHistory(url?.toString());
      },
      onProgressChanged: (controller, progress) {
        _update(progress: progress, isLoading: progress < 100);
      },
      onTitleChanged: (controller, title) {
        _update(title: title);
      },
      onUpdateVisitedHistory: (controller, url, isReload) async {
        _update(url: url?.toString());
        await _syncNavState(controller);
      },
      // 下载：交给统一的下载管理器（Dio），避免各平台下载器行为不一致
      onDownloadStartRequest: (controller, request) {
        final url = request.url.toString();
        ref.read(downloadsProvider.notifier).start(url);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已开始下载，可在菜单 → 下载中查看')),
          );
        }
      },
      // target=_blank 的链接改为在新标签打开
      onCreateWindow: (controller, action) async {
        final url = action.request.url?.toString();
        if (url != null && url.isNotEmpty) {
          ref
              .read(tabsProvider.notifier)
              .openTab(url: url, incognito: tab.incognito);
        }
        return true;
      },
    );
  }

  void _update({
    String? url,
    String? title,
    int? progress,
    bool? isLoading,
  }) {
    ref.read(tabsProvider.notifier).updateTab(
          tab.id,
          (t) => t.copyWith(
            url: url ?? t.url,
            title: title ?? t.title,
            progress: progress ?? t.progress,
            isLoading: isLoading ?? t.isLoading,
          ),
        );
  }

  Future<void> _syncNavState(InAppWebViewController controller) async {
    final back = await controller.canGoBack();
    final forward = await controller.canGoForward();
    ref.read(tabsProvider.notifier).updateTab(
          tab.id,
          (t) => t.copyWith(canGoBack: back, canGoForward: forward),
        );
  }

  Future<void> _recordHistory(String? url) async {
    if (url == null || tab.incognito) return;
    if (!UrlUtils.isSecure(url) && !url.startsWith('http://')) return;
    final repo = await ref.read(historyRepositoryProvider.future);
    await repo.add(title: tab.title, url: url);
    ref.invalidate(historyProvider);
  }
}
