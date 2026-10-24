import '../models/history_entry.dart';
import '../storage/prefs_store.dart';

/// 历史记录仓库，按访问时间倒序，超过上限自动裁剪
class HistoryRepository {
  HistoryRepository(this._store);

  final PrefsStore _store;
  static const _key = 'history.v1';
  static const int _limit = 2000;

  List<HistoryEntry>? _cache;

  Future<List<HistoryEntry>> all() async {
    if (_cache != null) return _cache!;
    _cache = _store.readList(_key).map(HistoryEntry.fromJson).toList()
      ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    return _cache!;
  }

  Future<List<HistoryEntry>> search(String keyword) async {
    final q = keyword.trim().toLowerCase();
    if (q.isEmpty) return all();
    return (await all())
        .where((e) =>
            e.title.toLowerCase().contains(q) || e.url.toLowerCase().contains(q))
        .toList();
  }

  Future<void> add({required String title, required String url}) async {
    if (url.startsWith('about:') || url.isEmpty) return;
    final list = await all();
    // 同一地址短时间内重复访问，只更新时间
    final idx = list.indexWhere((e) => e.url == url);
    if (idx >= 0) list.removeAt(idx);
    list.insert(0, HistoryEntry.create(title: title, url: url));
    if (list.length > _limit) list.removeRange(_limit, list.length);
    await _persist(list);
  }

  Future<void> remove(String id) async {
    final list = await all();
    list.removeWhere((e) => e.id == id);
    await _persist(list);
  }

  Future<void> clear() async {
    _cache = <HistoryEntry>[];
    await _store.writeList(_key, const []);
  }

  Future<void> _persist(List<HistoryEntry> list) async {
    _cache = list;
    await _store.writeList(_key, list.map((e) => e.toJson()).toList());
  }
}
