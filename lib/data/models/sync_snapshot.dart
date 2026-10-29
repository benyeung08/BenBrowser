import 'app_settings.dart';
import 'bookmark.dart';

/// 一份待同步的数据快照
///
/// 只同步「用户生产能力」相关的内容：书签和设置。
/// 历史记录刻意不同步——它量大、隐私敏感，且换设备时价值有限；
/// 标签页属于会话状态，同理不同步。
class SyncSnapshot {
  final List<Bookmark> bookmarks;
  final AppSettings settings;
  final DateTime updatedAt;

  const SyncSnapshot({
    required this.bookmarks,
    required this.settings,
    required this.updatedAt,
  });

  SyncSnapshot copyWith({
    List<Bookmark>? bookmarks,
    AppSettings? settings,
    DateTime? updatedAt,
  }) =>
      SyncSnapshot(
        bookmarks: bookmarks ?? this.bookmarks,
        settings: settings ?? this.settings,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(growable: false),
        'settings': settings.toJson(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SyncSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['bookmarks'];
    final list = raw is List ? raw : const <dynamic>[];
    return SyncSnapshot(
      bookmarks: [
        for (final item in list)
          if (item is Map) Bookmark.fromJson(Map<String, dynamic>.from(item)),
      ],
      settings: json['settings'] is Map
          ? AppSettings.fromJson(
              Map<String, dynamic>.from(json['settings'] as Map),
            )
          : const AppSettings(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// 合并策略：书签按 id 取并集，设置取较新的一份。
  ///
  /// 书签用并集而不是「整包覆盖」，是为了避免一侧新增的书签被另一侧
  /// 的旧快照抹掉——丢书签的代价远大于重复。
  /// 代价是删除操作不会跨设备传播（见 README 已知限制）。
  SyncSnapshot mergeWith(SyncSnapshot other) {
    final byId = <String, Bookmark>{
      for (final b in other.bookmarks) b.id: b,
    };
    for (final b in bookmarks) {
      byId.putIfAbsent(b.id, () => b);
    }
    final merged = byId.values.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final newerSettings =
        other.updatedAt.isAfter(updatedAt) ? other.settings : settings;

    return SyncSnapshot(
      bookmarks: merged,
      settings: newerSettings,
      updatedAt:
          updatedAt.isAfter(other.updatedAt) ? updatedAt : other.updatedAt,
    );
  }
}
