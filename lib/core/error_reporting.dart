import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// 全局错误兜底。
///
/// 没有这层时，Flutter 框架层与异步层的异常在 **release 包**里
/// 表现得非常隐蔽：
/// - 框架异常（布局越界、渲染抛错等）只会画一个灰色错误页或直接白屏
/// - 异步未捕获异常会静默丢弃，既不崩也不提示
/// 两者都没有日志，事后完全无法复盘。
///
/// 这里做三件事：
/// 1. [FlutterError.onError] —— 接管框架层异常
/// 2. [PlatformDispatcher.onError] —— 接管其余未捕获的异步异常
/// 3. [guard] —— 包住 main() 的启动流程，初始化阶段出错也能留下记录
///
/// 目前只做「记录」，不接任何第三方上报服务：浏览器属于隐私敏感应用，
/// 不该默认把用户数据往外发。之后要接 Sentry / Firebase 等，
/// 只需在 [_record] 里加一行转发即可，其余代码不用动。
class ErrorReporting {
  ErrorReporting._();

  static bool _installed = false;

  /// 安装全局处理器。幂等，重复调用无副作用。
  static Future<void> install() async {
    if (_installed) return;
    _installed = true;

    // 1) 框架层：build / layout / paint 期间抛的异常
    FlutterError.onError = (FlutterErrorDetails details) {
      // 仍交给默认处理，debug 下照常显示红屏、release 下画灰色错误页，
      // 我们只是顺带记录一份，不改变原有行为。
      FlutterError.presentError(details);
      _record('FlutterError', details.exception, details.stack);
    };

    // 2) 其余未捕获异常：async 里抛的、插件回调里抛的、
    //    以及 FlutterError.onError 本身没覆盖到的部分
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _record('Uncaught', error, stack);
      // 返回 true 表示已处理，不再走系统的默认崩溃流程。
      // release 下这样能避免直接闪退，用户至少还能继续使用。
      return true;
    };
  }

  /// 包住启动流程。出错时记录后继续抛出，不做静默吞掉——
  /// 吞掉只会让应用停在白屏，反而更难判断发生了什么。
  static Future<void> guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (e, stack) {
      _record('Startup', e, stack);
      rethrow;
    }
  }

  static void _record(String source, Object error, StackTrace? stack) {
    // debugPrint 在 release 下会被丢弃，用 log 才能进系统日志
    developer.log(
      '[$source] $error',
      name: 'BenBrowser',
      level: 1000, // SEVERE
      error: error,
      stackTrace: stack,
    );
    if (kDebugMode) {
      // 开发期直接打印，便于在控制台看到
      debugPrint('[$source] $error\n$stack');
    }
  }
}
