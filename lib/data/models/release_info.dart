/// 检查更新的结果类型
enum UpdateCheckResult {
  /// 已是最新
  upToDate,

  /// 有新版本
  available,

  /// 仓库还没发过 Release
  noRelease,

  /// 查询失败（没网 / 仓库不存在 / 配置有误）
  failed,
}

/// 一次检查更新的结论
class UpdateCheckOutcome {
  const UpdateCheckOutcome({
    required this.result,
    this.release,
    this.currentVersion = '',
    this.message,
  });

  final UpdateCheckResult result;
  final ReleaseInfo? release;
  final String currentVersion;
  final String? message;

  bool get hasUpdate => result == UpdateCheckResult.available;
}

/// GitHub Release 的附件
class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.browserDownloadUrl,
    this.size = 0,
  });

  final String name;
  final String browserDownloadUrl;
  final int size;

  bool get isApk => name.toLowerCase().endsWith('.apk');
  bool get isZip => name.toLowerCase().endsWith('.zip');

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) => ReleaseAsset(
        name: json['name'] as String? ?? '',
        browserDownloadUrl: json['browser_download_url'] as String? ?? '',
        size: json['size'] as int? ?? 0,
      );

  String get sizeText {
    if (size <= 0) return '';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).round()} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// 一次 Release 的信息
class ReleaseInfo {
  const ReleaseInfo({
    required this.tagName,
    required this.version,
    this.htmlUrl = '',
    this.name = '',
    this.notes = '',
    this.publishedAt,
    this.assets = const <ReleaseAsset>[],
  });

  /// 原始 tag，如 v0.2.0
  final String tagName;

  /// 去掉 v 前缀后的版本号，如 0.2.0
  final String version;

  /// Release 页面地址（桌面端跳浏览器下载用）
  final String htmlUrl;

  final String name;

  /// changelog 正文
  final String notes;

  final DateTime? publishedAt;

  final List<ReleaseAsset> assets;

  bool get hasNotes => notes.trim().isNotEmpty;

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    return ReleaseInfo(
      tagName: tag,
      version: _stripTag(tag),
      htmlUrl: json['html_url'] as String? ?? '',
      name: json['name'] as String? ?? '',
      notes: json['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      assets: (json['assets'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ReleaseAsset.fromJson)
          .toList(),
    );
  }

  static String _stripTag(String tag) {
    var v = tag.trim();
    if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
    return v;
  }
}
