import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/url_utils.dart';
import '../../state/providers.dart';

/// 书签列表
class BookmarksPage extends ConsumerStatefulWidget {
  const BookmarksPage({super.key});

  @override
  ConsumerState<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends ConsumerState<BookmarksPage> {
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(bookmarksProvider);
    final all = asyncList.valueOrNull ?? const [];
    final list = _keyword.isEmpty
        ? all
        : all
            .where((b) =>
                b.title.toLowerCase().contains(_keyword.toLowerCase()) ||
                b.url.toLowerCase().contains(_keyword.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('书签'),
        actions: [
          if (all.isNotEmpty)
            IconButton(
              tooltip: '清空书签',
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final repo = await ref.read(bookmarkRepositoryProvider.future);
                await repo.clear();
                ref.invalidate(bookmarksProvider);
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
                hintText: '搜索书签',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _keyword = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('还没有书签'))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return ListTile(
                        leading: const Icon(Icons.star_border),
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
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final repo =
                                await ref.read(bookmarkRepositoryProvider.future);
                            await repo.remove(item.id);
                            ref.invalidate(bookmarksProvider);
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
