import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/url_utils.dart';
import '../../data/models/browser_tab.dart';
import '../../state/providers.dart';
import '../browser/navigation.dart';

/// 新标签页：搜索入口 + 常用站点 + 最近访问
class NewTabPage extends ConsumerStatefulWidget {
  const NewTabPage({super.key, required this.tab});

  final BrowserTab tab;

  @override
  ConsumerState<NewTabPage> createState() => _NewTabPageState();
}

class _NewTabPageState extends ConsumerState<NewTabPage> {
  final _editor = TextEditingController();

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(settingsProvider).valueOrNull?.searchEngine ??
        SearchEngine.bing;
    final history = ref.watch(historyProvider).valueOrNull ?? const [];
    final recent = history.take(8).toList();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_outlined,
                      size: 32, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _editor,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => navigateTo(ref, widget.tab, v),
                decoration: InputDecoration(
                  hintText: '用${engine.label}搜索，或输入网址',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final site in AppConstants.shortcuts)
                    _ShortcutTile(
                      site: site,
                      onTap: () => navigateTo(ref, widget.tab, site.url),
                    ),
                ],
              ),
              if (recent.isNotEmpty) ...[
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '最近访问',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                for (final entry in recent)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, size: 18),
                    title: Text(
                      entry.title.isEmpty ? entry.url : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      UrlUtils.pretty(entry.url),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => navigateTo(ref, widget.tab, entry.url),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.site, required this.onTap});

  final ShortcutSite site;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                child: Icon(site.icon, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                site.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
