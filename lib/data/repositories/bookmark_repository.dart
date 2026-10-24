import '../models/bookmark.dart';
import '../storage/prefs_store.dart';

/// 书签仓库（内存缓存 + 持久化）
class BookmarkRepository {
  BookmarkRepository(this._store);

  final PrefsStore _store;
  static const _key = 'bookmarks.v1';

  List<Bookmark>? _cache;

  Future<List<Bookmark>> all() async {
    final cached = _cache;
    if (cached != null) return cached;

    final list = _store.readList(_key).map(Bookmark.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cache = list;
    return list;
  }

  Future<bool> exists(String url) async =>
      (await all()).any((b) => b.url == url);

  Future<void> add({required String title, required String url}) async {
    final list = (await all()).toList();
    if (list.any((b) => b.url == url)) return;
    list.insert(0, Bookmark.create(title: title, url: url));
    await _persist(list);
  }

  Future<void> remove(String id) async {
    final list = (await all()).toList()..removeWhere((b) => b.id == id);
    await _persist(list);
  }

  Future<void> clear() async {
    _cache = <Bookmark>[];
    await _store.writeList(_key, const <Map<String, dynamic>>[]);
  }

  Future<void> _persist(List<Bookmark> list) async {
    _cache = list;
    await _store.writeList(_key, list.map((e) => e.toJson()).toList());
  }
}
