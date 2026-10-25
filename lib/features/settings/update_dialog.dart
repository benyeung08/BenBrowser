import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/release_info.dart';
import '../../features/downloads/downloads_page.dart';
import '../../services/update_service.dart';
import '../../state/downloads_controller.dart';
import '../../state/providers.dart';

/// 发现新版本后的更新弹窗。
///
/// Android 上点「后台下载」交给浏览器的下载管理器（与网页下载同一套），
/// 进度在「下载」页可见，完成后点「安装」唤起系统安装器。
class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({
    super.key,
    required this.release,
    required this.currentVersion,
  });

  final ReleaseInfo release;
  final String currentVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(updateServiceProvider);
    final asset = svc.pickAsset(release);
    final canInstall = asset != null;
    final theme = Theme.of(context);
    final published = release.publishedAt;

    return AlertDialog(
      icon: const Icon(Icons.system_update_alt),
      title: Text('发现新版本 ${release.version}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(
                    avatar: const Icon(Icons.arrow_upward, size: 14),
                    label: Text('当前 $currentVersion'),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (published != null)
                    Chip(
                      avatar: const Icon(Icons.event, size: 14),
                      label: Text(_formatDate(published)),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (asset != null && asset.size > 0)
                    Chip(
                      avatar: const Icon(Icons.sd_card, size: 14),
                      label: Text(asset.sizeText),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (release.hasNotes) ...[
                const SizedBox(height: 12),
                Text('更新内容', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  release.notes,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                canInstall
                    ? '下载在后台进行，进度可在「菜单 → 下载」查看；'
                        '完成后点安装，按提示允许安装未知应用即可。'
                    : '桌面端不支持静默安装，将打开浏览器下载页，'
                        '下载后手动替换即可。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('稍后再说'),
        ),
        TextButton.icon(
          icon: const Icon(Icons.open_in_browser, size: 18),
          label: const Text('浏览器打开'),
          onPressed: () {
            final url = asset?.browserDownloadUrl ?? release.htmlUrl;
            unawaited(svc.openInBrowser(url));
          },
        ),
        if (canInstall && asset != null)
          FilledButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('后台下载'),
            onPressed: () => _startDownload(context, ref, asset),
          ),
      ],
    );
  }

  Future<void> _startDownload(
    BuildContext context,
    WidgetRef ref,
    ReleaseAsset asset,
  ) async {
    // 交给浏览器自带的下载管理器，进度与网页下载一致
    await ref.read(downloadsProvider.notifier).start(
          asset.browserDownloadUrl,
          fileName: asset.name,
          kind: DownloadKind.update,
          version: release.version,
        );
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('v${release.version} 正在后台下载'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => _openDownloads(context),
        ),
      ),
    );
  }

  static Future<void> _openDownloads(BuildContext context) async {
    final nav = Navigator.of(context);
    await nav.push(
      MaterialPageRoute<void>(builder: (_) => const DownloadsPage()),
    );
  }

  String _formatDate(DateTime time) {
    final local = time.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
