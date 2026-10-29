import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/models/app_settings.dart';
import '../data/models/browser_tab.dart';
import '../state/providers.dart';

/// 标签页集合 + 当前激活索引
class TabsState {
  final List<BrowserTab> tabs;
  final int activeIndex;

  /// 最近使用顺序，最前面是最近激活过的标签 id。
  ///
  /// 用于决定哪些标签可以保留 WebView 实例（详见
  /// [AppConstants.maxLiveWebViews]）：开太多标签时，最久未使用的会被
  /// 「挂起」，等重新切回时再重建并重新加载。
  final List<String> recent;

  const TabsState({
    this.tabs = const <BrowserTab>[],
    this.activeIndex = 0,
    this.recent = const <String>[],
  });

  bool get isEmpty => tabs.isEmpty;

  /// 把 id 提到最近使用的最前面
  List<String> _touch(List<String> list, String id) =>
      <String>[id, ...list.where((e) => e != id)];

  /// 安全的当前索引（增删标签后不会越界）
  int get safeIndex {
    if (tabs.isEmpty) return 0;
    if (activeIndex < 0) return 0;
    final last = tabs.length - 1;
    return activeIndex > last ? last : activeIndex;
  }

  BrowserTab? get activeTab => tabs.isEmpty ? null : tabs[safeIndex];

  TabsState copyWith({
    List<BrowserTab>? tabs,
    int? activeIndex,
    List<String>? recent,
  }) =>
      TabsState(
        tabs: tabs ?? this.tabs,
        activeIndex: activeIndex ?? this.activeIndex,
        recent: recent ?? this.recent,
      );

  /// 应当保留 WebView 实例的标签 id 集合。
  ///
  /// 标签数不超过 [AppConstants.maxLiveWebViews] 时全部保留——
  /// 日常开两三个标签完全不受影响，行为与之前一致。
  /// 只有标签真的开多了，才按最近使用顺序砍掉最久未用的。
  Set<String> get liveTabIds {
    if (tabs.length <= AppConstants.maxLiveWebViews) {
      return <String>{for (final t in tabs) t.id};
    }
    final keep = <String>{for (final t in tabs) t.id};
    final ordered = <String>[
      // 当前标签永远排在最前：正在看的页面被挂起是最糟的体验
      if (!isEmpty) tabs[safeIndex].id,
      ...recent.where(keep.contains),
      ...tabs.map((t) => t.id).where((id) => !recent.contains(id)),
    ];
    // 去重保序（当前标签可能同时也在 recent 里）
    final seen = <String>{};
    final result = <String>[];
    for (final id in ordered) {
      if (seen.add(id)) result.add(id);
    }
    return result.take(AppConstants.maxLiveWebViews).toSet();
  }
}

final tabsProvider = NotifierProvider<TabsController, TabsState>(
  TabsController.new,
);

class TabsController extends Notifier<TabsState> {
  @override
  TabsState build() => const TabsState();

  AppSettings? get _settings =>
      ref.read(settingsProvider).valueOrNull;

  /// 应用启动后确保至少有一个标签
  void ensureInitialTab({String? homeUrl}) {
    if (state.tabs.isNotEmpty) return;
    openTab(url: homeUrl ?? _settings?.homeUrl ?? AppConstants.defaultHome);
  }

  /// 新建一个标签。达到上限时返回 false（此前是静默 return，
  /// 用户点「+」没任何反应，看起来像应用卡了），由调用方决定是否提示。
  bool openTab({
    String url = AppConstants.newTabUrl,
    bool? incognito,
    bool select = true,
  }) {
    if (state.tabs.length >= AppConstants.maxTabs) return false;
    final useIncognito = incognito ?? _settings?.incognitoByDefault ?? false;
    final tab = BrowserTab.create(url: url, incognito: useIncognito);
    final tabs = [...state.tabs, tab];
    state = state.copyWith(
      tabs: tabs,
      activeIndex: select ? tabs.length - 1 : state.activeIndex,
      recent: _touch(state.recent, tab.id),
    );
    return true;
  }

  void closeTab(String id) {
    final index = state.tabs.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final tabs = [...state.tabs]..removeAt(index);
    final nextActive = tabs.isEmpty
        ? 0
        : state.copyWith(tabs: tabs).safeIndex;
    state = state.copyWith(
      tabs: tabs,
      activeIndex: nextActive,
      recent: state.recent.where((e) => e != id).toList(),
    );
    ref.read(webViewRegistryProvider).remove(id);
  }

  void selectTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    final id = state.tabs[index].id;
    state = state.copyWith(
      activeIndex: index,
      recent: _touch(state.recent, id),
    );
  }

  void updateTab(String id, BrowserTab Function(BrowserTab) updater) {
    final index = state.tabs.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final tabs = [...state.tabs];
    tabs[index] = updater(tabs[index]);
    state = state.copyWith(tabs: tabs);
  }

  /// 关闭除指定标签外的所有标签
  void closeOthers(String id) {
    final keep = state.tabs.where((t) => t.id == id).toList();
    for (final t in state.tabs) {
      if (t.id != id) ref.read(webViewRegistryProvider).remove(t.id);
    }
    state = state.copyWith(tabs: keep, activeIndex: 0, recent: <String>[id]);
  }

  void closeAll() {
    for (final t in state.tabs) {
      ref.read(webViewRegistryProvider).remove(t.id);
    }
    state = const TabsState();
  }
}
