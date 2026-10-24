import '../../core/constants.dart';

/// 全局设置（持久化到 SharedPreferences）
class AppSettings {
  final String homeUrl;
  final String searchEngineId;
  final String userAgentModeId;
  final String customUserAgent;
  final bool javaScriptEnabled;
  final bool incognitoByDefault;
  final bool restoreTabsOnLaunch;
  final ThemeModeSetting themeMode;

  const AppSettings({
    this.homeUrl = AppConstants.defaultHome,
    this.searchEngineId = SearchEngine.bing.id,
    this.userAgentModeId = UserAgentPreset.system.id,
    this.customUserAgent = '',
    this.javaScriptEnabled = true,
    this.incognitoByDefault = false,
    this.restoreTabsOnLaunch = true,
    this.themeMode = ThemeModeSetting.system,
  });

  SearchEngine get searchEngine => SearchEngine.fromId(searchEngineId);

  UserAgentPreset get userAgentPreset => UserAgentPreset.fromId(userAgentModeId);

  /// 实际下发给 WebView 的 UA，null 表示跟随系统
  String? get effectiveUserAgent {
    if (userAgentModeId == 'custom') {
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
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        homeUrl: json['homeUrl'] as String? ?? AppConstants.defaultHome,
        searchEngineId: json['searchEngineId'] as String? ?? SearchEngine.bing.id,
        userAgentModeId:
            json['userAgentModeId'] as String? ?? UserAgentPreset.system.id,
        customUserAgent: json['customUserAgent'] as String? ?? '',
        javaScriptEnabled: json['javaScriptEnabled'] as bool? ?? true,
        incognitoByDefault: json['incognitoByDefault'] as bool? ?? false,
        restoreTabsOnLaunch: json['restoreTabsOnLaunch'] as bool? ?? true,
        themeMode: ThemeModeSetting.values.firstWhere(
          (e) => e.name == json['themeMode'],
          orElse: () => ThemeModeSetting.system,
        ),
      );
}

enum ThemeModeSetting { system, light, dark }
