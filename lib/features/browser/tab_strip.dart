import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/tabs_controller.dart';

/// 标签条：移动端紧凑 chip，桌面端稍宽
class TabStrip extends ConsumerWidget {
  const TabStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tabsProvider);
    if (state.tabs.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.tabs.length,
              itemBuilder: (context, index) {
                final tab = state.tabs[index];
                final active = index == state.safeIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Material(
                    color: active
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => ref
                          .read(tabsProvider.notifier)
                          .selectTab(index),
                      child: SizedBox(
                        width: 160,
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Icon(
                              tab.incognito
                                  ? Icons.visibility_off
                                  : Icons.language,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tab.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            SizedBox(
                              width: 28,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                tooltip: '关闭标签',
                                icon: const Icon(Icons.close),
                                onPressed: () => ref
                                    .read(tabsProvider.notifier)
                                    .closeTab(tab.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: '新建标签页',
            icon: const Icon(Icons.add, size: 20),
            onPressed: () {
              // 静默失败会让人以为按钮坏了，达到上限时明确提示
              if (!ref.read(tabsProvider.notifier).openTab()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('标签数量已达上限，请先关闭一些'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
