import 'package:flutter/foundation.dart';

/// 当前运行的宿主平台。
///
/// 两端内核与更新方式都有差异：
/// - Android：系统 WebView，窄屏布局，更新可在应用内安装
/// - Windows：WebView2（需 Win10 1809+ 与 WebView2 Runtime）
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
