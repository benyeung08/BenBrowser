/// 下载任务状态
enum DownloadStatus { running, done, canceled, failed }

class DownloadTask {
  final String id;
  final String url;
  final String fileName;
  final String? savePath;
  final int received;
  final int total;
  final DownloadStatus status;
  final DateTime createdAt;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    this.savePath,
    this.received = 0,
    this.total = 0,
    this.status = DownloadStatus.running,
    required this.createdAt,
  });

  double get percent {
    if (total <= 0) return status == DownloadStatus.done ? 1 : 0;
    return (received / total).clamp(0.0, 1.0);
  }

  DownloadTask copyWith({
    String? savePath,
    int? received,
    int? total,
    DownloadStatus? status,
  }) =>
      DownloadTask(
        id: id,
        url: url,
        fileName: fileName,
        savePath: savePath ?? this.savePath,
        received: received ?? this.received,
        total: total ?? this.total,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
