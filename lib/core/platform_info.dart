import 'package:flutter/foundation.dart';

/// 当前运行的宿主平台。
///
/// 两端内核与更新方式都有差异：
/// - Android：系统 WebView，窄屏布局，更新可在应用内安装
/// - Windows：WebView2（需 Win10 1809+ 与 WebView2 Runtime）
///
/// 两端都要求登录后才能浏览，见 [requireLoginToBrowse]。
enum HostPlatform { android, windows, linux, unknown }

HostPlatform get hostPlatform {
  if (kIsWeb) return HostPlatform.unknown;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return HostPlatform.android;
    case TargetPlatform.windows:
      return HostPlatform.windows;
    case TargetPlatform.linux:
      return HostPlatform.linux;
    default:
      return HostPlatform.unknown;
  }
}

bool get isDesktopHost =>
    hostPlatform == HostPlatform.windows || hostPlatform == HostPlatform.linux;

bool get isAndroidHost => hostPlatform == HostPlatform.android;

/// 手机端屏幕窄，底部工具栏更顺手；Windows 窗口宽，按钮平铺在顶栏即可。
bool get useCompactLayout => hostPlatform == HostPlatform.android;

/// 是否要求先登录才能浏览。
///
/// Android 与 Windows **都需要**：书签与设置的云同步挂在账号上，
/// 两个端统一成同一套进入方式，行为更好预期。
///
/// 注意：真正挡住界面时还有一道「云服务是否已配置」的判断，
/// 见 [LoginGate] —— 没配置的话不能把用户锁死在登录页，
/// 会给出「暂不登录，直接使用」的出口。
///
/// 想整体去掉登录墙，把这个 getter 改成 `false` 即可。
bool get requireLoginToBrowse =>
    hostPlatform == HostPlatform.android ||
    hostPlatform == HostPlatform.windows;
