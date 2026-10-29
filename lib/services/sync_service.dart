import '../core/constants.dart';
import '../data/models/sync_snapshot.dart';
import 'account_service.dart';

/// 云同步：把书签与设置存到 Supabase 的一张表里
///
/// 表结构（只需建一次，SQL 见 README）：
///   user_id     text primary key
///   payload     jsonb
///   updated_at  timestamptz
///
/// 依赖 [AccountService] 提供的客户端，未登录或未配置时所有操作都是空操作，
/// 不会抛异常——同步失败不该影响正常浏览。
class SyncService {
  const SyncService(this._account);

  final AccountService _account;

  static const String _table = CloudConfig.syncTable;

  /// 已登录且后端可用
  bool get isAvailable => _account.client != null && _account.userId != null;

  /// 拉取云端快照；没有数据、未登录或出错时返回 null
  Future<SyncSnapshot?> pull() async {
    final client = _account.client;
    final userId = _account.userId;
    if (client == null || userId == null) return null;

    try {
      final row = await client
          .from(_table)
          .select('payload')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;

      final payload = row['payload'];
      if (payload is! Map) return null;
      return SyncSnapshot.fromJson(Map<String, dynamic>.from(payload));
    } catch (_) {
      // 表不存在、RLS 拒了、断网……都当作「没有远端数据」
      return null;
    }
  }

  /// 上传本地快照，成功返回 true
  Future<bool> push(SyncSnapshot snapshot) async {
    final client = _account.client;
    final userId = _account.userId;
    if (client == null || userId == null) return false;

    try {
      await client.from(_table).upsert({
        'user_id': userId,
        'payload': snapshot.toJson(),
        'updated_at': snapshot.updatedAt.toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
