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

/// 大屏判定阈值（dp），与 Android 平台判定「大屏」的标准一致。
///
/// Android 17（API 37）在最小宽度 >= 600dp 的屏幕上会**直接忽略**
/// `screenOrientation`、`resizeableActivity`、`minAspectRatio`、
/// `maxAspectRatio` 以及 `setRequestedOrientation()`。
/// 所以布局必须按窗口实际尺寸来定，而不是按「这是手机还是桌面」。
const double kLargeScreenDp = 600;

/// 当前窗口是否应按窄屏（手机式）布局渲染。
///
/// 传 `MediaQuery.sizeOf(context).shortestSide` 进来即可。
///
/// 为什么不直接用平台判断：Android 手机、平板、折叠屏展开、分屏、
/// 桌面窗口模式都可能给出完全不同的窗口尺寸，同一台设备在不同场景下
/// 需要不同的布局。按窗口宽度判断才能同时满足这些情况——
/// 这也正是 Android 17 强制要求的行为。
bool isCompactWindow(double shortestSideDp) => shortestSideDp < kLargeScreenDp;

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
