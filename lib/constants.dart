import 'package:flutter/material.dart';

/// 应用内常量：默认主页、搜索引擎模板、快捷站点
class AppConstants {
  AppConstants._();

  static const String appName = 'Nimbus';
  static const String defaultHome = 'https://www.bing.com';
  static const String newTabUrl = 'about:blank';

  static const int maxTabs = 20;

  /// 新标签页展示的快捷站点
  static const List<ShortcutSite> shortcuts = [
    ShortcutSite('GitHub', 'https://github.com', Icons.code),
    ShortcutSite('Bing', 'https://www.bing.com', Icons.travel_explore),
    ShortcutSite('Bilibili', 'https://www.bilibili.com', Icons.smart_display),
    ShortcutSite('知乎', 'https://www.zhihu.com', Icons.forum),
    ShortcutSite('掘金', 'https://juejin.cn', Icons.article),
    ShortcutSite('MDN', 'https://developer.mozilla.org', Icons.menu_book),
  ];
}

class ShortcutSite {
  final String name;
  final String url;
  final IconData icon;

  const ShortcutSite(this.name, this.url, this.icon);
}

/// 可选搜索引擎
class SearchEngine {
  final String id;
  final String label;
  final String template;

  const SearchEngine(this.id, this.label, this.template);

  static const bing = SearchEngine('bing', 'Bing', 'https://www.bing.com/search?q={q}');
  static const google = SearchEngine('google', 'Google', 'https://www.google.com/search?q={q}');
  static const duckduckgo =
      SearchEngine('duck', 'DuckDuckGo', 'https://duckduckgo.com/?q={q}');
  static const baidu = SearchEngine('baidu', '百度', 'https://www.baidu.com/s?wd={q}');

  static const List<SearchEngine> all = [bing, google, duckduckgo, baidu];

  static SearchEngine fromId(String id) => all.firstWhere(
        (e) => e.id == id,
        orElse: () => bing,
      );
}

/// User-Agent 预设
class UserAgentPreset {
  final String id;
  final String label;
  final String? value;

  const UserAgentPreset(this.id, this.label, this.value);

  static const system = UserAgentPreset('system', '跟随系统', null);
  static const desktop = UserAgentPreset(
    'desktop',
    '桌面版 Chrome',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  );
  static const mobile = UserAgentPreset(
    'mobile',
    '移动版 Chrome (Android)',
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
  );

  static const List<UserAgentPreset> all = [system, desktop, mobile];

  static UserAgentPreset fromId(String id) => all.firstWhere(
        (e) => e.id == id,
        orElse: () => system,
      );
}
