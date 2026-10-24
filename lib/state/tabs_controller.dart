import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/models/app_settings.dart';
import '../data/models/browser_tab.dart';
import '../state/providers.dart';

/// 标签页集合 + 当前激活索引
class TabsState {
  final List<BrowserTab> tabs;
  final int activeIndex;

  const TabsState({this.tabs = const <BrowserTab>[], this.activeIndex = 0});

  bool get isEmpty => tabs.isEmpty;

  /// 安全的当前索引（增删标签后不会越界）
  int get safeIndex {
    if (tabs.isEmpty) return 0;
    if (activeIndex < 0) return 0;
    final last = tabs.length - 1;
    return activeIndex > last ? last : activeIndex;
  }

  BrowserTab? get activeTab => tabs.isEmpty ? null : tabs[safeIndex];

  TabsState copyWith({List<BrowserTab>? tabs, int? activeIndex}) => TabsState(
        tabs: tabs ?? this.tabs,
        activeIndex: activeIndex ?? this.activeIndex,
      );
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

  void openTab({
    String url = AppConstants.newTabUrl,
    bool? incognito,
    bool select = true,
  }) {
    if (state.tabs.length >= AppConstants.maxTabs) return;
    final useIncognito = incognito ?? _settings?.incognitoByDefault ?? false;
    final tab = BrowserTab.create(url: url, incognito: useIncognito);
    final tabs = [...state.tabs, tab];
    state = state.copyWith(
      tabs: tabs,
      activeIndex: select ? tabs.length - 1 : state.activeIndex,
    );
  }

  void closeTab(String id) {
    final index = state.tabs.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final tabs = [...state.tabs]..removeAt(index);
    final nextActive = tabs.isEmpty
        ? 0
        : state.copyWith(tabs: tabs).safeIndex;
    state = state.copyWith(tabs: tabs, activeIndex: nextActive);
    ref.read(webViewRegistryProvider).remove(id);
  }

  void selectTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    state = state.copyWith(activeIndex: index);
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
    state = state.copyWith(tabs: keep, activeIndex: 0);
  }

  void closeAll() {
    for (final t in state.tabs) {
      ref.read(webViewRegistryProvider).remove(t.id);
    }
    state = const TabsState();
  }
}
