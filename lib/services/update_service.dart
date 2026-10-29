import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/platform_info.dart';
import '../data/models/release_info.dart';

/// 语义化版本比较：a > b 返回正数，相等 0，a < b 负数。
/// 容忍 v 前缀、+build 后缀与位数不齐（1.2 vs 1.2.0 视为相等）。
int compareVersion(String a, String b) {
  List<int> parts(String v) {
    final clean = v.trim().toLowerCase().replaceFirst(RegExp(r'^v'), '');
    final main = clean.split('+').first;
    return main
        .split(RegExp(r'[.\-_]'))
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
  }

  final pa = parts(a);
  final pb = parts(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// 应用内更新：读取 GitHub 最新 Release 并按平台处理。
///
/// - Android：下载 APK 后用系统安装器打开（无需存储权限，落在应用目录）
/// - Windows：直接跳浏览器下载（桌面端没有统一的静默安装途径）
class UpdateService {
  UpdateService(this._dio);

  final Dio _dio;

  static const Duration _timeout = Duration(seconds: 15);

  /// 可选的 GitHub token，用于提高 API 限流额度。
  ///
  /// 未鉴权时 GitHub 只允许 **60 次/小时/IP**，而 checkUpdateOnLaunch
  /// 默认是开的，同一个网络里多设备同时启动很容易 403。
  /// 传入方式：`--dart-define=GITHUB_TOKEN=ghp_xxx`
  /// （只需要 public_repo 之外的**只读**权限，甚至可以不给任何 scope）
  static final String? githubToken = () {
    final v = const String.fromEnvironment('GITHUB_TOKEN');
    return v.isEmpty ? null : v;
  }();

  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// 查询最新 Release 并与当前版本比对
  Future<UpdateCheckOutcome> check(String repoSlug) async {
    final slug = repoSlug.trim();
    if (slug.isEmpty || slug.contains('OWNER')) {
      return const UpdateCheckOutcome(
        result: UpdateCheckResult.failed,
        message: '还没配置 GitHub 仓库，请在设置里填写 owner/repo',
      );
    }

    String current;
    try {
      current = await currentVersion();
    } catch (_) {
      current = '';
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/$slug/releases/latest',
        options: Options(
          headers: <String, String>{
            'Accept': 'application/vnd.github+json',
            if (githubToken != null) 'Authorization': 'Bearer $githubToken',
          },
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
          connectTimeout: _timeout,
          // 404 不算异常，交给下面的分支判断
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = response.data;
      if (response.statusCode != 200 || data == null) {
        return UpdateCheckOutcome(
          result: UpdateCheckResult.noRelease,
          currentVersion: current,
          message: '该仓库还没有发布 Release（打 tag 后由 CI 自动生成）',
        );
      }

      if (response.statusCode == 403 || response.statusCode == 429) {
        return UpdateCheckOutcome(
          result: UpdateCheckResult.failed,
          currentVersion: current,
          message: githubToken == null
              ? 'GitHub API 限流（未鉴权仅 60 次/小时/IP），稍后再试'
              : 'GitHub API 限流，稍后再试',
        );
      }

      final release = ReleaseInfo.fromJson(data);
      if (release.tagName.isEmpty) {
        return UpdateCheckOutcome(
          result: UpdateCheckResult.noRelease,
          currentVersion: current,
          message: '未获取到版本信息',
        );
      }

      // 拿不到当前版本（PackageInfo 失败）时不能贸然判定「有更新」——
      // 空字符串会被解析成 0，任何正式版本号都大于它，结果就是每次启动
      // 都弹一次更新提示，而用户其实已经是最新版了。
      if (current.isEmpty) {
        return UpdateCheckOutcome(
          result: UpdateCheckResult.upToDate,
          release: release,
          currentVersion: current,
          message: '无法读取当前版本，已跳过比较',
        );
      }

      if (compareVersion(release.version, current) <= 0) {
        return UpdateCheckOutcome(
          result: UpdateCheckResult.upToDate,
          release: release,
          currentVersion: current,
        );
      }

      return UpdateCheckOutcome(
        result: UpdateCheckResult.available,
        release: release,
        currentVersion: current,
      );
    } catch (e) {
      return UpdateCheckOutcome(
        result: UpdateCheckResult.failed,
        currentVersion: current,
        message: '检查更新失败：${e.toString()}',
      );
    }
  }

  /// 按当前平台挑选合适的安装包
  ReleaseAsset? pickAsset(ReleaseInfo release) {
    final assets = release.assets;
    if (assets.isEmpty) return null;

    switch (hostPlatform) {
      case HostPlatform.android:
        // --split-per-abi 会产出三个 APK，优先 arm64（现代机型通用）
        for (final a in assets) {
          if (a.isApk && a.name.contains('arm64')) return a;
        }
        for (final a in assets) {
          if (a.isApk) return a;
        }
        return null;
      case HostPlatform.windows:
        for (final a in assets) {
          if (a.isZip && a.name.toLowerCase().contains('windows')) return a;
        }
        return null;
      default:
        return null;
    }
  }

  /// Android 可以在应用内下载并安装；桌面端没有静默安装途径，只能跳浏览器
  bool get canInstallInApp => hostPlatform == HostPlatform.android;

  /// 桌面端 / 兜底：用系统浏览器打开下载页
  Future<bool> openInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
