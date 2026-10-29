import 'package:ben_browser/data/models/app_settings.dart';
import 'package:ben_browser/data/models/bookmark.dart';
import 'package:ben_browser/data/models/sync_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

Bookmark _bm(String id, DateTime at) => Bookmark(
      id: id,
      title: 't-$id',
      url: 'https://example.com/$id',
      createdAt: at,
    );

void main() {
  final t1 = DateTime(2026, 1, 1);
  final t2 = DateTime(2026, 6, 1);

  group('SyncSnapshot 序列化', () {
    test('往返一致', () {
      final s = SyncSnapshot(
        bookmarks: [_bm('a', t1)],
        settings: const AppSettings().copyWith(homeUrl: 'https://a.dev'),
        updatedAt: t2,
      );
      final back = SyncSnapshot.fromJson(s.toJson());

      expect(back.bookmarks.length, 1);
      expect(back.bookmarks.first.id, 'a');
      expect(back.settings.homeUrl, 'https://a.dev');
      expect(back.updatedAt, t2);
    });

    test('字段缺失时不抛异常', () {
      final back = SyncSnapshot.fromJson(<String, dynamic>{});
      expect(back.bookmarks, isEmpty);
    });
  });

  group('SyncSnapshot 合并', () {
    test('书签按 id 取并集', () {
      final local = SyncSnapshot(
        bookmarks: [_bm('a', t1)],
        settings: const AppSettings(),
        updatedAt: t1,
      );
      final remote = SyncSnapshot(
        bookmarks: [_bm('b', t2)],
        settings: const AppSettings(),
        updatedAt: t2,
      );

      final merged = local.mergeWith(remote);
      final ids = merged.bookmarks.map((b) => b.id).toList()..sort();

      expect(ids, ['a', 'b']);
    });

    test('同 id 只保留一条', () {
      final local = SyncSnapshot(
        bookmarks: [_bm('a', t1), _bm('b', t1)],
        settings: const AppSettings(),
        updatedAt: t1,
      );
      final remote = SyncSnapshot(
        bookmarks: [_bm('a', t2)],
        settings: const AppSettings(),
        updatedAt: t2,
      );

      expect(local.mergeWith(remote).bookmarks.length, 2);
    });

    test('设置取较新的一份', () {
      final older = SyncSnapshot(
        bookmarks: const <Bookmark>[],
        settings: const AppSettings().copyWith(javaScriptEnabled: false),
        updatedAt: t1,
      );
      final newer = SyncSnapshot(
        bookmarks: const <Bookmark>[],
        settings: const AppSettings().copyWith(javaScriptEnabled: true),
        updatedAt: t2,
      );

      // older 与 newer 合并：无论谁在前，都应取 t2 那份
      expect(older.mergeWith(newer).settings.javaScriptEnabled, isTrue);
      expect(newer.mergeWith(older).settings.javaScriptEnabled, isTrue);
    });

    test('合并后的时间戳取较新的', () {
      final a = SyncSnapshot(
        bookmarks: const <Bookmark>[],
        settings: const AppSettings(),
        updatedAt: t1,
      );
      final b = SyncSnapshot(
        bookmarks: const <Bookmark>[],
        settings: const AppSettings(),
        updatedAt: t2,
      );

      expect(a.mergeWith(b).updatedAt, t2);
      expect(b.mergeWith(a).updatedAt, t2);
    });
  });
}
