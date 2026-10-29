import 'package:flutter_test/flutter_test.dart';
import 'package:ben_browser/core/constants.dart';
import 'package:ben_browser/data/models/browser_tab.dart';
import 'package:ben_browser/state/tabs_controller.dart';

void main() {
  TabsState build(int count, {int activeIndex = 0, List<String>? recent}) =>
      TabsState(
        tabs: [
          for (var i = 0; i < count; i++)
            BrowserTab(id: 't$i', url: 'https://a.com/$i'),
        ],
        activeIndex: activeIndex,
        recent: recent ?? [for (var i = count - 1; i >= 0; i--) 't$i'],
      );

  group('TabsState.liveTabIds', () {
    test('标签数不超过上限时全部保留（日常使用行为不变）', () {
      final state = build(AppConstants.maxLiveWebViews);
      expect(state.liveTabIds.length, AppConstants.maxLiveWebViews);
      expect(state.liveTabIds, contains('t0'));
    });

    test('超出上限时按最近使用裁剪', () {
      final state = build(10);
      final live = state.liveTabIds;
      expect(live.length, AppConstants.maxLiveWebViews);
      // 最近使用的应该被留下
      expect(live, contains('t9'));
      // 最久未使用的被挂起
      expect(live, isNot(contains('t4')));
    });

    test('当前激活的标签永远不被挂起', () {
      // 反向 recent：t0 最久未用，但它是当前标签
      final state = build(10, activeIndex: 0);
      expect(state.liveTabIds, contains('t0'));
    });

    test('recent 里含已关闭标签时不会泄漏', () {
      final state = build(10, recent: ['closed-id', 't9', 't8']);
      final live = state.liveTabIds;
      expect(live, isNot(contains('closed-id')));
      expect(live.length <= AppConstants.maxLiveWebViews, isTrue);
    });
  });
}
