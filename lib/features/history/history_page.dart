import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/url_utils.dart';
// ★ HistoryEntry 类型本体，缺它会导致 non_type_as_type_argument
import '../../data/models/history_entry.dart';
import '../../state/providers.dart';

/// 历史记录（无痕标签产生的记录不会入库）
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(historyProvider).valueOrNull ?? <HistoryEntry>[];
    final list = _keyword.isEmpty
        ? all
        : all
            .where((e) =>
                e.title.toLowerCase().contains(_keyword.toLowerCase()) ||
                e.url.toLowerCase().contains(_keyword.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        actions: [
          if (all.isNotEmpty)
            IconButton(
              tooltip: '清空历史',
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final repo = await ref.read(historyRepositoryProvider.future);
                await repo.clear();
                ref.invalidate(historyProvider);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索历史',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('暂无浏览记录'))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(
                          item.title.isEmpty ? item.url : item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          UrlUtils.pretty(item.url),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () async {
                            final repo =
                                await ref.read(historyRepositoryProvider.future);
                            await repo.remove(item.id);
                            ref.invalidate(historyProvider);
                          },
                        ),
                        onTap: () => Navigator.of(context).pop(item.url),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
