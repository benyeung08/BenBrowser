import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/models/bookmark.dart';
import '../data/models/browser_tab.dart';
import '../data/models/history_entry.dart';
import '../data/repositories/bookmark_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/storage/prefs_store.dart';

/// 持久化存储单例
final prefsStoreProvider =
    FutureProvider<PrefsStore>((ref) => PrefsStore.open());

final settingsRepositoryProvider =
    FutureProvider<SettingsRepository>((ref) async {
  final store = await ref.watch(prefsStoreProvider.future);
  return SettingsRepository(store);
});

final bookmarkRepositoryProvider =
    FutureProvider<BookmarkRepository>((ref) async {
  final store = await ref.watch(prefsStoreProvider.future);
  return BookmarkRepository(store);
});

final historyRepositoryProvider =
    FutureProvider<HistoryRepository>((ref) async {
  final store = await ref.watch(prefsStoreProvider.future);
  return HistoryRepository(store);
});

/// 全局设置（异步加载 + 保存）
final settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final repo = await ref.watch(settingsRepositoryProvider.future);
    return repo.load();
  }

  /// 注意：方法名不能叫 update —— Riverpod 的 AsyncNotifier 本身就有
  /// `Future<T> update(FutureOr<T> Function(T) cb, {...})`，同名会被判
  /// invalid_override。这里改叫 save。
  Future<void> save(AppSettings settings) async {
    state = AsyncData(settings);
    final repo = await ref.read(settingsRepositoryProvider.future);
    await repo.save(settings);
  }

  Future<void> patch(AppSettings Function(AppSettings) fn) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await save(fn(current));
  }
}

/// WebView 控制器注册表（tabId -> controller）
final webViewRegistryProvider = Provider<WebViewRegistry>((ref) {
  final registry = WebViewRegistry();
  ref.onDispose(registry.dispose);
  return registry;
});

/// 书签列表（需要刷新时 invalidate 本 provider）
final bookmarksProvider = FutureProvider<List<Bookmark>>((ref) async {
  final repo = await ref.watch(bookmarkRepositoryProvider.future);
  return repo.all();
});

/// 历史记录列表
final historyProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  final repo = await ref.watch(historyRepositoryProvider.future);
  return repo.all();
});
