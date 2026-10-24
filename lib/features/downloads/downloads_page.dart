import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/download_task.dart';
import '../../state/downloads_controller.dart';

/// 下载管理页
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
                return ListTile(
                  leading: Icon(_icon(task.status)),
                  title: Text(
                    task.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: task.percent),
                      const SizedBox(height: 4),
                      Text(
                        task.status == DownloadStatus.done
                            ? task.savePath ?? '已完成'
                            : '${(task.percent * 100).toInt()}%',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  trailing: task.status == DownloadStatus.done
                      ? IconButton(
                          tooltip: '打开',
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () =>
                              ref.read(downloadsProvider.notifier).open(task),
                        )
                      : IconButton(
                          tooltip: '移除',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => ref
                              .read(downloadsProvider.notifier)
                              .remove(task.id),
                        ),
                );
              },
            ),
    );
  }

  IconData _icon(DownloadStatus status) => switch (status) {
        DownloadStatus.done => Icons.check_circle_outline,
        DownloadStatus.failed => Icons.error_outline,
        DownloadStatus.canceled => Icons.cancel_outlined,
        DownloadStatus.running => Icons.downloading,
      };
}
