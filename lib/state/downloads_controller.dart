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
    final name = fileName ?? _guessFileName(url);
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
    unawaited(_run(task, name));
    return id;
  }

  Future<void> _run(DownloadTask task, String name) async {
    try {
      final dir = await _downloadDir;
      // 同名文件先删掉：更新包重下时避免安装器提示「包体不一致」
      final savePath = p.join(dir.path, name);
      final file = File(savePath);
      if (await file.exists()) await file.delete();

      await Dio().download(
        task.url,
        savePath,
        onReceiveProgress: (received, total) {
          _patch(task.id, (t) => t.copyWith(received: received, total: total));
        },
      );
      _patch(
        task.id,
        (t) => t.copyWith(status: DownloadStatus.done, savePath: savePath),
      );
    } catch (_) {
      _patch(task.id, (t) => t.copyWith(status: DownloadStatus.failed));
    }
  }

  void cancel(String id) =>
      _patch(id, (t) => t.copyWith(status: DownloadStatus.canceled));

  void remove(String id) => state = state.where((t) => t.id != id).toList();

  void clearFinished() =>
      state = state.where((t) => t.status == DownloadStatus.running).toList();

  /// 普通文件：用系统默认方式打开
  Future<void> open(DownloadTask task) async {
    final path = task.savePath;
    if (path == null || !File(path).existsSync()) return;
    await OpenFilex.open(path);
  }

  /// 安装更新包（Android）。显式带上 MIME，避免部分 ROM 识别不出 APK。
  Future<void> install(DownloadTask task) async {
    final path = task.savePath;
    if (path == null || !File(path).existsSync()) return;
    await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
  }

  void _patch(String id, DownloadTask Function(DownloadTask) fn) {
    state = [
      for (final t in state)
        if (t.id == id) fn(t) else t,
    ];
  }

  String _guessFileName(String url) {
    final uri = Uri.tryParse(url);
    final seg = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? [];
    if (seg.isNotEmpty) return seg.last;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'download_$stamp.bin';
  }
}
