import 'package:flutter/foundation.dart';

/// 当前运行的宿主平台（浏览器内部按平台做最小差异适配）
enum HostPlatform { android, windows, macos, linux, unknown }

HostPlatform get hostPlatform {
  if (kIsWeb) return HostPlatform.unknown;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return HostPlatform.android;
    case TargetPlatform.windows:
      return HostPlatform.windows;
    case TargetPlatform.macOS:
      return HostPlatform.macos;
    case TargetPlatform.linux:
      return HostPlatform.linux;
    default:
      return HostPlatform.unknown;
  }
}

bool get isDesktopHost =>
    hostPlatform == HostPlatform.windows ||
    hostPlatform == HostPlatform.macos ||
    hostPlatform == HostPlatform.linux;

/// 桌面端窗口更宽，标签条与工具栏可以平铺
bool get useCompactLayout => hostPlatform == HostPlatform.android;
