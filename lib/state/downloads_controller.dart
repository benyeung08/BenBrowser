import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/models/download_task.dart';

final downloadsProvider =
    NotifierProvider<DownloadsController, List<DownloadTask>>(
  DownloadsController.new,
);

/// 下载管理：三端统一使用 Dio 直连下载到应用数据目录下。
/// 这样 Android 13+ 无需申请存储权限，桌面端也不会污染系统目录。
///
/// 应用更新包也走这里（kind = DownloadKind.update），好处是：
/// - 进度、暂停、失败重试与网页下载完全一致，不用再写一套
/// - 用户在「下载」页就能看到更新包，点「安装」直接唤起系统安装器
class DownloadsController extends Notifier<List<DownloadTask>> {
  @override
  List<DownloadTask> build() => const <DownloadTask>[];

  Directory? _dirCache;

  /// 每个任务一个 CancelToken。
  ///
  /// 之前 cancel() 只改了状态，Dio 的下载仍在后台跑完，
  /// 结束时还会把状态覆盖回 done —— 表现为「点了取消却下载成功了」。
  final Map<String, CancelToken> _tokens = <String, CancelToken>{};

  Future<Directory> get _downloadDir async {
    final cached = _dirCache;
    if (cached != null) return cached;

    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'BenBrowser', 'Downloads'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _dirCache = dir;
    return dir;
  }

  /// 启动一个下载任务，返回任务 id（调用方可据此在 state 里观察进度）
  Future<String> start(
    String url, {
    String? fileName,
    DownloadKind kind = DownloadKind.normal,
    String version = '',
  }) async {
    final name = _uniqueName(fileName ?? _guessFileName(url));

    // 同一个地址正在下载时不要重复起任务：两个 Dio 会写同一个 savePath，
    // 结果是文件损坏，而 UI 上只看到一个进度条在跳，很难排查。
    for (final t in state) {
      if (t.url == url && t.status == DownloadStatus.running) return t.id;
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final task = DownloadTask(
      id: id,
      url: url,
      fileName: name,
      createdAt: DateTime.now(),
      kind: kind,
      version: version,
    );
    state = [...state, task];
    _tokens[id] = CancelToken();
    unawaited(_run(task, name));
    return id;
  }

  Future<void> _run(DownloadTask task, String name) async {
    String? savePath;
    try {
      final dir = await _downloadDir;
      // 同名文件先删掉：更新包重下时避免安装器提示「包体不一致」
      savePath = p.join(dir.path, name);
      final file = File(savePath);
      if (await file.exists()) await file.delete();

      final token = _tokens[task.id];
      await Dio().download(
        task.url,
        savePath,
        cancelToken: token,
        onReceiveProgress: (received, total) {
          _patch(task.id, (t) => t.copyWith(received: received, total: total));
        },
      );
      // 取消时 Dio 会抛异常，能走到这里说明真的完成了
      _patch(
        task.id,
        (t) => t.copyWith(status: DownloadStatus.done, savePath: savePath),
      );
    } catch (e) {
      // 用户主动取消时 Dio 抛的是 DioException(cancel)，不应标成 failed
      final canceled = e is DioException && e.type == DioExceptionType.cancel;
      if (!canceled) {
        _patch(task.id, (t) => t.copyWith(status: DownloadStatus.failed));
      }
      // 半截文件必须删掉：留着的话下次「打开」会拿到一个损坏的文件，
      // 而列表里显示的是「已取消」，用户根本想不到是这个残留造成的。
      if (canceled && savePath != null) {
        try {
          final f = File(savePath);
          if (await f.exists()) await f.delete();
        } catch (_) {
          // 删不掉就算了，不影响主流程
        }
      }
    } finally {
      _tokens.remove(task.id);
    }
  }

  void cancel(String id) {
    _tokens[id]?.cancel('用户取消');
    _tokens.remove(id);
    _patch(id, (t) => t.copyWith(status: DownloadStatus.canceled));
  }

  void remove(String id) {
    _tokens[id]?.cancel('任务被移除');
    _tokens.remove(id);
    state = state.where((t) => t.id != id).toList();
  }

  void clearFinished() {
    for (final t in state) {
      if (t.status != DownloadStatus.running) {
        _tokens.remove(t.id);
      }
    }
    state = state.where((t) => t.status == DownloadStatus.running).toList();
  }

  /// 普通文件：用系统默认方式打开
  Future<void> open(DownloadTask task) async {
    final path = task.savePath;
    if (path == null || !await File(path).exists()) return;
    await OpenFilex.open(path);
  }

  /// 安装更新包（Android）。显式带上 MIME，避免部分 ROM 识别不出 APK。
  Future<void> install(DownloadTask task) async {
    final path = task.savePath;
    if (path == null || !await File(path).exists()) return;
    await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
  }

  void _patch(String id, DownloadTask Function(DownloadTask) fn) {
    state = [
      for (final t in state)
        if (t.id == id) fn(t) else t,
    ];
  }

  /// 生成一个不会与已有任务冲突的文件名。
  ///
  /// 之前同名文件直接覆盖：两个不同地址下载到同一个 `a.zip` 时，
  /// 后完成的会把先完成的悄悄替换掉，用户拿到的是错误的文件。
  /// 现在遇到冲突就加 `(1)` `(2)` 后缀。
  String _uniqueName(String base) {
    final inUse = <String>{for (final t in state) t.fileName};
    if (!inUse.contains(base)) return base;

    final dot = base.lastIndexOf('.');
    final stem = dot > 0 ? base.substring(0, dot) : base;
    final ext = dot > 0 ? base.substring(dot) : '';
    for (var i = 1; i < 1000; i++) {
      final candidate = '$stem($i)$ext';
      if (!inUse.contains(candidate)) return candidate;
    }
    // 极端情况下兜底，不至于死循环
    return '${stem}_${DateTime.now().millisecondsSinceEpoch}$ext';
  }

  String _guessFileName(String url) {
    final uri = Uri.tryParse(url);
    final seg = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? [];
    final base = seg.isNotEmpty
        ? seg.last
        : 'download_${DateTime.now().millisecondsSinceEpoch}.bin';
    // 顺手去掉路径分隔符，避免恶意服务端用 "../../x" 之类的文件名
    return _uniqueName(base.replaceAll(RegExp(r'[/\\]'), '_'));
  }
}
