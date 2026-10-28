import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../data/models/bookmark.dart';
import '../data/models/browser_tab.dart';
import '../data/models/history_entry.dart';
import '../data/repositories/bookmark_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/models/user_account.dart';
import '../data/storage/prefs_store.dart';
import '../services/account_service.dart';
import '../services/sync_service.dart';
import '../services/update_service.dart';

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

/// 应用内更新服务（内部自带 Dio 实例）
final updateServiceProvider =
    Provider<UpdateService>((ref) => UpdateService(Dio()));


/// ---------------------------------------------------------------- 账号与同步

/// 账号服务实例。在 main() 里完成 initialize 后用 overrideWithValue 注入，
/// 保证整个应用拿到的是同一个已经初始化好的实例。
final accountServiceProvider = Provider<AccountService>((ref) {
  throw UnimplementedError('必须在 main() 里用 overrideWithValue 注入');
});

/// 当前登录账号；未登录为 null。监听 Supabase 的登录状态变化。
final accountProvider = NotifierProvider<AccountController, UserAccount?>(
  AccountController.new,
);

class AccountController extends Notifier<UserAccount?> {
  StreamSubscription<UserAccount?>? _sub;

  @override
  UserAccount? build() {
    final svc = ref.watch(accountServiceProvider);

    // 未配置时订阅不到流，直接保持未登录状态即可
    if (svc.isReady) {
      _sub?.cancel();
      _sub = svc.authStateChanges.listen(
        (account) => state = account,
        onError: (_) {}, // 断网等情况会走到这里，忽略即可
      );
      ref.onDispose(() {
        _sub?.cancel();
        _sub = null;
      });
    }
    return svc.currentAccount;
  }
}

/// 云同步服务
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(accountServiceProvider));
});

/// 上次同步成功的时刻。仅保存在内存中，重开应用会重置。
/// 真正的「已同步」状态以云端 updated_at 为准，这里只用于展示。
final lastSyncAtProvider = StateProvider<DateTime?>((ref) => null);

/// 用户是否点了「暂不登录，直接使用」。
///
/// 只在「要求登录的平台 + 云服务尚未配置」这一组合下有意义——
/// 此时根本登不进去，必须给一个出口，否则应用完全不可用。
/// 仅存内存：重开应用会重新要求登录，配置好之后这条路自然就走不到了。
final loginSkippedProvider = StateProvider<bool>((ref) => false);
