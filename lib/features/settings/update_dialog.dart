import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/download_task.dart';
import '../../data/models/release_info.dart';
import '../../features/downloads/downloads_page.dart';
import '../../services/desktop_update.dart';
import '../../services/update_service.dart';
import '../../state/downloads_controller.dart';
import '../../state/providers.dart';

/// 发现新版本后的更新弹窗。
///
/// - **Android**：点「后台下载」交给浏览器的下载管理器（与网页下载同一套），
///   进度在「下载」页可见，完成后点「安装」唤起系统安装器
/// - **Windows**：点「下载并安装」→ 应用内下载解压 → 自动退出 →
///   脚本替换文件并重启，全程无需手动操作
class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({
    super.key,
    required this.release,
    required this.currentVersion,
  });

  final ReleaseInfo release;
  final String currentVersion;

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _updating = false;
  double _progress = 0;
  String? _error;

  bool get _canSelfUpdate => WindowsUpdater.isSupported;

  Future<void> _startDownload(ReleaseAsset asset) async {
    // Android：交给浏览器自带的下载管理器，进度与网页下载一致
    await ref.read(downloadsProvider.notifier).start(
          asset.browserDownloadUrl,
          fileName: asset.name,
          kind: DownloadKind.update,
          version: widget.release.version,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('v${widget.release.version} 正在后台下载'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => _openDownloads(context),
        ),
      ),
    );
  }

  /// Windows：下载 → 解压 → 启动替换脚本 → 退出，由脚本完成重启
  Future<void> _installWindows(ReleaseAsset asset) async {
    setState(() {
      _updating = true;
      _progress = 0;
      _error = null;
    });

    try {
      await WindowsUpdater(Dio()).applyUpdate(
        zipUrl: asset.browserDownloadUrl,
        version: widget.release.version,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      // 走到这里说明脚本已经脱离本进程启动，可以放心退出
      if (mounted) setState(() => _progress = 1);
      exit(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _updating = false;
        _error = '更新失败：$e';
      });
    }
  }

  static Future<void> _openDownloads(BuildContext context) async {
    final nav = Navigator.of(context);
    await nav.push(
      MaterialPageRoute<void>(builder: (_) => const DownloadsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = ref.watch(updateServiceProvider);
    final asset = svc.pickAsset(widget.release);
    final canInstall = svc.canInstallInApp && asset != null;
    final theme = Theme.of(context);
    final published = widget.release.publishedAt;

    return AlertDialog(
      icon: const Icon(Icons.system_update_alt),
      title: Text('发现新版本 ${widget.release.version}'),
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
                    label: Text('当前 ${widget.currentVersion}'),
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
              if (widget.release.hasNotes) ...[
                const SizedBox(height: 12),
                Text('更新内容', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  widget.release.notes,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              if (_updating) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text(
                  _progress >= 1
                      ? '即将重启以完成更新…'
                      : '正在下载并安装 ${(_progress * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else if (_error != null)
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else
                Text(
                  canInstall
                      ? '下载在后台进行，进度可在「菜单 → 下载」查看；'
                          '完成后点安装，按提示允许安装未知应用即可。'
                      : _canSelfUpdate
                          ? '下载完成后应用会自动退出并重启，'
                              '无需手动替换文件。'
                          : '当前平台不支持应用内安装，将打开浏览器下载页。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (!_updating) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后再说'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: const Text('浏览器打开'),
            onPressed: () {
              final url = asset?.browserDownloadUrl ?? widget.release.htmlUrl;
              unawaited(svc.openInBrowser(url));
            },
          ),
        ],
        if (_updating)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (canInstall)
          FilledButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('后台下载'),
            onPressed: () => _startDownload(asset),
          )
        else if (_canSelfUpdate && asset != null)
          FilledButton.icon(
            icon: const Icon(Icons.install_desktop, size: 18),
            label: const Text('下载并安装'),
            onPressed: () => _installWindows(asset),
          ),
      ],
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
