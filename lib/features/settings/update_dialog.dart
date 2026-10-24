import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/release_info.dart';
import '../../services/update_service.dart';

/// 发现新版本后的更新弹窗。
/// Android 支持下载后直接唤起安装器，桌面端统一跳浏览器下载。
class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({
    super.key,
    required this.release,
    required this.currentVersion,
    this.service,
  });

  final ReleaseInfo release;
  final String currentVersion;
  final UpdateService? service;

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  UpdateService get _service =>
      widget.service ?? ref.read(updateServiceProvider);

  ReleaseAsset? get _asset => _service.pickAsset(widget.release);

  bool get _canInstall => _service.canInstallInApp && _asset != null;

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    final asset = _asset;
    final theme = Theme.of(context);
    // 取到局部变量再判空：Dart 不会对 public field 做空值提升，
    // 用局部变量可以彻底避免 `!`
    final published = release.publishedAt;
    final error = _error;

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
              const SizedBox(height: 12),
              if (release.hasNotes) ...[
                Text('更新内容', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  release.notes,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (_canInstall) ...[
                const SizedBox(height: 12),
                Text(
                  '下载完成后会唤起系统安装器。若没弹出安装界面，'
                  '请在系统设置里允许本应用「安装未知应用」。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (_downloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress > 0 ? _progress : null),
                const SizedBox(height: 6),
                Text(
                  _progress > 0
                      ? '下载中 ${(_progress * 100).toInt()}%'
                      : '准备下载…',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],
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
          onPressed: () => _openInBrowser(),
        ),
        if (_canInstall)
          FilledButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('下载并安装'),
            onPressed: _downloading ? null : () => _downloadAndInstall(),
          )
        else if (asset != null)
          FilledButton.icon(
            icon: const Icon(Icons.download, size: 18),
            label: const Text('下载安装包'),
            onPressed: _downloading ? null : () => _openInBrowser(asset),
          ),
      ],
    );
  }

  Future<void> _downloadAndInstall() async {
    final asset = _asset;
    if (asset == null) return;

    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    String? path;
    try {
      path = await _service.download(asset, (received, total) {
        if (!mounted) return;
        setState(() {
          _progress = total > 0 ? received / total : 0;
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = '下载失败：$e';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _downloading = false);

    Navigator.of(context).pop();
    await _service.install(path);
  }

  Future<void> _openInBrowser([ReleaseAsset? asset]) async {
    final url = (asset ?? _asset)?.browserDownloadUrl ?? widget.release.htmlUrl;
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
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
