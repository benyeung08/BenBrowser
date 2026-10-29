import '../../core/constants.dart';

/// 全局设置（持久化到 SharedPreferences）
class AppSettings {
  final String homeUrl;
  final String searchEngineId;
  final String userAgentModeId;
  final String customUserAgent;
  final bool javaScriptEnabled;
  final bool incognitoByDefault;
  /// 启动时恢复上次打开的标签。
  ///
  /// ⚠️ **当前尚未实现**：全项目没有任何地方读取它，也没有对应的 UI 开关。
  /// 默认值此前是 `true`，等于向用户宣称了一个不存在的功能，
  /// 所以改成 `false`——等真正实现了再改回来。
  bool get isTabRestoreImplemented => false;

  final bool restoreTabsOnLaunch;
  final ThemeModeSetting themeMode;

  /// 检查更新用的 GitHub 仓库，格式 owner/repo
  final String repoSlug;
  final bool checkUpdateOnLaunch;

  const AppSettings({
    this.homeUrl = AppConstants.defaultHome,
    // const 构造的默认值里不能用 SearchEngine.bing.id（实例字段访问），
    // 改用 static const 常量，否则报 const_eval_property_access
    this.searchEngineId = SearchEngine.defaultId,
    this.userAgentModeId = UserAgentPreset.systemId,
    this.customUserAgent = '',
    this.javaScriptEnabled = true,
    this.incognitoByDefault = false,
    // 见 [isTabRestoreImplemented]：功能未实现，默认不能是 true
    this.restoreTabsOnLaunch = false,
    this.themeMode = ThemeModeSetting.system,
    this.repoSlug = AppConstants.defaultRepoSlug,
    this.checkUpdateOnLaunch = true,
  });

  SearchEngine get searchEngine => SearchEngine.fromId(searchEngineId);

  UserAgentPreset get userAgentPreset => UserAgentPreset.fromId(userAgentModeId);

  /// 实际下发给 WebView 的 UA，null 表示跟随系统
  String? get effectiveUserAgent {
    if (userAgentModeId == UserAgentPreset.customId) {
      return customUserAgent.trim().isEmpty ? null : customUserAgent.trim();
    }
    return userAgentPreset.value;
  }

  AppSettings copyWith({
    String? homeUrl,
    String? searchEngineId,
    String? userAgentModeId,
    String? customUserAgent,
    bool? javaScriptEnabled,
    bool? incognitoByDefault,
    bool? restoreTabsOnLaunch,
    ThemeModeSetting? themeMode,
    String? repoSlug,
    bool? checkUpdateOnLaunch,
  }) =>
      AppSettings(
        homeUrl: homeUrl ?? this.homeUrl,
        searchEngineId: searchEngineId ?? this.searchEngineId,
        userAgentModeId: userAgentModeId ?? this.userAgentModeId,
        customUserAgent: customUserAgent ?? this.customUserAgent,
        javaScriptEnabled: javaScriptEnabled ?? this.javaScriptEnabled,
        incognitoByDefault: incognitoByDefault ?? this.incognitoByDefault,
        restoreTabsOnLaunch: restoreTabsOnLaunch ?? this.restoreTabsOnLaunch,
        themeMode: themeMode ?? this.themeMode,
        repoSlug: repoSlug ?? this.repoSlug,
        checkUpdateOnLaunch: checkUpdateOnLaunch ?? this.checkUpdateOnLaunch,
      );

  Map<String, dynamic> toJson() => {
        'homeUrl': homeUrl,
        'searchEngineId': searchEngineId,
        'userAgentModeId': userAgentModeId,
        'customUserAgent': customUserAgent,
        'javaScriptEnabled': javaScriptEnabled,
        'incognitoByDefault': incognitoByDefault,
        'restoreTabsOnLaunch': restoreTabsOnLaunch,
        'themeMode': themeMode.name,
        'repoSlug': repoSlug,
        'checkUpdateOnLaunch': checkUpdateOnLaunch,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        homeUrl: json['homeUrl'] as String? ?? AppConstants.defaultHome,
        searchEngineId:
            json['searchEngineId'] as String? ?? SearchEngine.defaultId,
        userAgentModeId:
            json['userAgentModeId'] as String? ?? UserAgentPreset.systemId,
        customUserAgent: json['customUserAgent'] as String? ?? '',
        javaScriptEnabled: json['javaScriptEnabled'] as bool? ?? true,
        incognitoByDefault: json['incognitoByDefault'] as bool? ?? false,
        restoreTabsOnLaunch: json['restoreTabsOnLaunch'] as bool? ?? false,
        themeMode: ThemeModeSetting.values.firstWhere(
          (e) => e.name == json['themeMode'],
          orElse: () => ThemeModeSetting.system,
        ),
        repoSlug: json['repoSlug'] as String? ?? AppConstants.defaultRepoSlug,
        checkUpdateOnLaunch: json['checkUpdateOnLaunch'] as bool? ?? true,
      );
}

enum ThemeModeSetting { system, light, dark }
