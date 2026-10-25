import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/download_task.dart';
import '../../state/downloads_controller.dart';

/// 下载管理页。
/// 应用更新包（kind == update）也在这里，Android 上可直接点「安装」。
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载'),
        actions: [
          if (tasks.any((t) => t.status != DownloadStatus.running))
            IconButton(
              tooltip: '清除已完成',
              icon: const Icon(Icons.delete_sweep),
              onPressed: () =>
                  ref.read(downloadsProvider.notifier).clearFinished(),
            ),
        ],
      ),
      body: tasks.isEmpty
          ? const Center(child: Text('暂无下载任务'))
          : ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _TaskTile(task: task);
              },
            ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(downloadsProvider.notifier);
    final theme = Theme.of(context);
    final canInstall = task.isUpdate && task.status == DownloadStatus.done;

    return ListTile(
      leading: Icon(_icon(task.status)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              task.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (task.isUpdate)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                task.version.isEmpty ? '更新包' : '更新 v${task.version}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(value: task.percent),
          const SizedBox(height: 4),
          Text(
            _statusText(task),
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
      trailing: canInstall
          ? FilledButton.icon(
              icon: const Icon(Icons.install_mobile, size: 18),
              label: const Text('安装'),
              onPressed: () => controller.install(task),
            )
          : (task.status == DownloadStatus.done
              ? IconButton(
                  tooltip: '打开',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => controller.open(task),
                )
              : IconButton(
                  tooltip: '移除',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => controller.remove(task.id),
                )),
    );
  }

  static String _statusText(DownloadTask task) {
    if (task.status == DownloadStatus.failed) return '下载失败';
    if (task.status == DownloadStatus.canceled) return '已取消';
    if (task.status == DownloadStatus.done) {
      return task.isUpdate ? '下载完成，可安装' : (task.savePath ?? '已完成');
    }
    return '${(task.percent * 100).toInt()}%';
  }

  static IconData _icon(DownloadStatus status) => switch (status) {
        DownloadStatus.done => Icons.check_circle_outline,
        DownloadStatus.failed => Icons.error_outline,
        DownloadStatus.canceled => Icons.cancel_outlined,
        DownloadStatus.running => Icons.downloading,
      };
}
