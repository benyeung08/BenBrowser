import 'package:flutter/material.dart';

/// 应用内常量：默认主页、搜索引擎模板、快捷站点
class AppConstants {
  AppConstants._();

  static const String appName = 'BenBrowser';
  static const String defaultHome = 'https://www.bing.com';
  static const String newTabUrl = 'about:blank';

  static const int maxTabs = 20;

  /// 同时保留 WebView 实例的标签上限。
  ///
  /// 每个标签是一个真实的 WebView（Android: 系统 WebView / Windows: WebView2），
  /// 实例本身几十 MB 起，加上页面内容，20 个标签全在内存里极易 OOM。
  ///
  /// 标签数**不超过**这个值时全部保留（日常开两三个标签不受影响）；
  /// 超过了才按最近使用顺序挂起最久未用的，切回时重建并重新加载。
  ///
  /// 想要「永不挂起」就把它设成 >= maxTabs，代价是多标签下的内存占用。
  static const int maxLiveWebViews = 6;

  /// 检查更新用的 GitHub 仓库（owner/repo）。
  /// ★ 推送到你自己的仓库后，把这里改成你的，或在设置页里直接改。
  static const String defaultRepoSlug = 'OWNER/ben_browser';

  /// 仓库为空时的兜底提示
  static const String repoPlaceholder = 'OWNER';

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

  /// 默认引擎的 id。
  /// 注意：const 表达式里不能访问实例字段（SearchEngine.bing.id 会报
  /// const_eval_property_access），所以另开一个 static const 供默认值使用。
  static const String defaultId = 'bing';

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

  /// 同上：const 上下文里用这个代替 UserAgentPreset.system.id
  static const String systemId = 'system';
  static const String customId = 'custom';

  static UserAgentPreset fromId(String id) => all.firstWhere(
        (e) => e.id == id,
        orElse: () => system,
      );
}

/// 云端账号与同步（Google / Microsoft 登录 + 书签与设置同步）
///
/// 后端用 Supabase：它同时提供 OAuth（Google、Microsoft/Azure）和数据库，
/// 一个服务同时解决「登录」和「同步」，且 OAuth 的 client id / secret
/// 都放在 Supabase 后台，不必写进客户端代码。
///
/// 启用步骤见 README「账号与云同步」。在填入真实值之前，
/// [CloudConfig.isConfigured] 为 false，应用不会去连网络，功能整体降级。
class CloudConfig {
  CloudConfig._();

  /// Supabase 项目 URL，形如 https://xxxx.supabase.co
  /// ★ 改成你自己的（或用 --dart-define=SUPABASE_URL=... 注入）
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL',
  );

  /// Supabase publishable key（旧称 anon key）
  /// ★ 改成你自己的（或用 --dart-define=SUPABASE_PUBLISHABLE_KEY=... 注入）
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'YOUR_SUPABASE_PUBLISHABLE_KEY',
  );

  /// 同步数据存放的表名，需先在 Supabase 建好（建表 SQL 见 README）
  static const String syncTable = 'benbrowser_sync';

  /// OAuth 回调用的自定义 scheme。Android 需要它在 Manifest 里声明
  /// intent-filter（由 tool/patch_platform.py 自动注入），且与 Supabase
  /// 后台的 Redirect URLs 保持一致。
  static const String redirectScheme = 'com.ben.benbrowser';
  static const String oauthRedirectUrl = '$redirectScheme://login-callback/';

  /// 还没填真实值就视为「未配置」。
  /// 用占位符前缀判断，避免把 'YOUR_...' 当成真地址发出请求。
  static bool get isConfigured {
    if (supabaseUrl.startsWith('YOUR_')) return false;
    if (supabasePublishableKey.startsWith('YOUR_')) return false;
    return Uri.tryParse(supabaseUrl)?.hasScheme == true;
  }
}
