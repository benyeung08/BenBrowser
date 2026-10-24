import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 单个标签页的状态快照。
/// 真正的 InAppWebViewController 不放在这里，改由 webview_registry 按 id 托管。
class BrowserTab {
  final String id;
  final String url;
  final String title;
  final int progress;
  final bool isLoading;
  final bool incognito;
  final bool canGoBack;
  final bool canGoForward;

  const BrowserTab({
    required this.id,
    required this.url,
    this.title = '',
    this.progress = 0,
    this.isLoading = false,
    this.incognito = false,
    this.canGoBack = false,
    this.canGoForward = false,
  });

  factory BrowserTab.create({
    String url = 'about:blank',
    bool incognito = false,
    String title = '',
  }) =>
      BrowserTab(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        url: url,
        title: title,
        incognito: incognito,
      );

  String get displayTitle =>
      title.trim().isEmpty ? (url.isEmpty ? '新标签页' : url) : title;

  BrowserTab copyWith({
    String? url,
    String? title,
    int? progress,
    bool? isLoading,
    bool? canGoBack,
    bool? canGoForward,
  }) =>
      BrowserTab(
        id: id,
        url: url ?? this.url,
        title: title ?? this.title,
        progress: progress ?? this.progress,
        isLoading: isLoading ?? this.isLoading,
        incognito: incognito,
        canGoBack: canGoBack ?? this.canGoBack,
        canGoForward: canGoForward ?? this.canGoForward,
      );
}

/// 把 controller 与 tab id 关联起来的注册表
class WebViewRegistry {
  final Map<String, InAppWebViewController> _map = {};

  InAppWebViewController? get(String id) => _map[id];

  void register(String id, InAppWebViewController controller) => _map[id] = controller;

  void remove(String id) => _map.remove(id);

  bool contains(String id) => _map.containsKey(id);

  void dispose() => _map.clear();
}
