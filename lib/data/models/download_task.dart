/// 下载任务状态
enum DownloadStatus { running, done, canceled, failed }

/// 任务来源：普通网页下载 / 应用更新包
enum DownloadKind {
  /// 网页触发的下载
  normal,

  /// 从设置「更新」区触发的应用更新包（APK / 安装包）
  update,
}

class DownloadTask {
  final String id;
  final String url;
  final String fileName;
  final String? savePath;
  final int received;
  final int total;
  final DownloadStatus status;
  final DateTime createdAt;

  /// 任务来源
  final DownloadKind kind;

  /// kind == update 时记录目标版本号，用于在下载列表里显示
  final String version;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    this.savePath,
    this.received = 0,
    this.total = 0,
    this.status = DownloadStatus.running,
    required this.createdAt,
    this.kind = DownloadKind.normal,
    this.version = '',
  });

  bool get isUpdate => kind == DownloadKind.update;

  double get percent {
    if (total <= 0) return status == DownloadStatus.done ? 1 : 0;
    return (received / total).clamp(0.0, 1.0);
  }

  DownloadTask copyWith({
    String? savePath,
    int? received,
    int? total,
    DownloadStatus? status,
    DownloadKind? kind,
    String? version,
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
        kind: kind ?? this.kind,
        version: version ?? this.version,
      );
}
