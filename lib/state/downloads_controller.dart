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

/// 下载管理：三端统一使用 Dio 直连下载到应用数据目录下的 Downloads 文件夹。
/// 这样 Android 13+ 无需申请存储权限，桌面端也不会污染系统目录。
class DownloadsController extends Notifier<List<DownloadTask>> {
  @override
  List<DownloadTask> build() => const <DownloadTask>[];

  Future<Directory> get _downloadDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'BenBrowser', 'Downloads'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> start(String url, {String? fileName}) async {
    final name = fileName ?? _guessFileName(url);
    final task = DownloadTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: url,
      fileName: name,
      createdAt: DateTime.now(),
    );
    state = [...state, task];

    try {
      final dir = await _downloadDir;
      final savePath = p.join(dir.path, name);
      await Dio().download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          _patch(
            task.id,
            (t) => t.copyWith(received: received, total: total),
          );
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

  void remove(String id) =>
      state = state.where((t) => t.id != id).toList();

  void clearFinished() =>
      state = state
          .where((t) => t.status == DownloadStatus.running)
          .toList();

  Future<void> open(DownloadTask task) async {
    final path = task.savePath;
    if (path == null || !File(path).existsSync()) return;
    await OpenFilex.open(path);
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
