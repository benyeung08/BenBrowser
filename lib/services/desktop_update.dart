import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

/// Windows 应用内一键更新。
///
/// **为什么需要绕一圈**：Windows 不允许覆盖正在运行的 `.exe` / `.dll`——
/// 主程序自己没法替换自己。做法是先把新版本解压到临时目录，再启动一个
/// **脱离本进程的批处理脚本**：脚本等到主程序退出、文件不再被占用后，
/// 把新文件拷进安装目录并重启程序。
///
/// 相比引入 WinSparkle 那类框架，这套方案的好处是：
/// - 复用 CI 已有的 zip 产物，不需要额外制作安装包（installer）
/// - 不需要 DSA 密钥、不需要维护 appcast.xml
/// - 继续走 GitHub Releases 检测，changelog 照常展示
///
/// 代价是替换逻辑自己维护，且要求**安装目录可写**（别装在 Program Files）。
class WindowsUpdater {
  WindowsUpdater(this._dio);

  final Dio _dio;

  static bool get isSupported => Platform.isWindows;

  /// 当前 exe 所在目录，也就是安装目录
  static String get installDir => File(Platform.resolvedExecutable).parent.path;

  /// 下载 → 解压 → 启动替换脚本。
  ///
  /// 返回后调用方应当立刻退出应用（`exit(0)`），把剩下的事交给脚本。
  Future<void> applyUpdate({
    required String zipUrl,
    required String version,
    void Function(double progress)? onProgress,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('应用内更新仅支持 Windows');
    }

    final tempRoot =
        await Directory.systemTemp.createTemp('benbrowser_update_');
    final zipPath = p.join(tempRoot.path, 'update.zip');
    final pkgDir = p.join(tempRoot.path, 'pkg');

    try {
      // 1) 下载
      await _dio.download(
        zipUrl,
        zipPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call((received / total).clamp(0.0, 0.90));
          }
        },
      );

      // 2) 解压
      await _extract(zipPath, pkgDir);
      onProgress?.call(0.93);

      // 3) 定位新版本的主程序
      final newExe = await _findExe(Directory(pkgDir));
      if (newExe == null) {
        throw StateError('更新包里没有找到可执行文件');
      }
      final targetExe = p.join(installDir, p.basename(newExe));

      // 关键：复制源取 **exe 所在的那一层目录**，而不是解压根目录。
      // 若 zip 带顶层目录（例如 BenBrowser-windows-x64\...），
      // 直接拷 pkgDir 会把整个目录套进安装目录，真正的 exe 得不到替换——
      // 表现是「更新完成但仍旧版本」，且完全静默。
      final copySrc = p.dirname(newExe);

      // 4) 写替换脚本（把路径直接烧进脚本，避免命令行引号问题）
      final logFile = p.join(tempRoot.path, 'updater.log');
      final bat = File(p.join(tempRoot.path, 'updater.bat'));
      await bat.writeAsString(
        _buildScript(
          pid: pid.toString(),
          src: copySrc,
          dst: installDir,
          exe: targetExe,
          log: logFile,
          tmpRoot: tempRoot.path,
        ),
        flush: true,
      );

      // 5) 脱离本进程启动。cmd 会立刻返回，脚本独立存活。
      //
      // 清理责任移交给脚本（脚本会 rmdir 整个 tempRoot）。
      // 之前只在**失败**分支删临时目录，成功时 update.zip（几十 MB）
      // 连同 bat/log 会永久留在系统临时目录，每更新一次累积一份。
      await Process.start(
        'cmd.exe',
        ['/c', 'start', '""', '/MIN', bat.path],
        mode: ProcessStartMode.detached,
      );
      onProgress?.call(1);
    } catch (e) {
      // 失败就把临时目录清掉，下次重试不受影响
      try {
        await tempRoot.delete(recursive: true);
      } catch (_) {
        // 忽略清理失败
      }
      rethrow;
    }
  }

  /// 解压 zip。顺带做目录穿越防护（zip slip）。
  Future<void> _extract(String zipPath, String dest) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final destDir = Directory(dest);
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    // 先解析符号链接拿到真实路径，否则 /link -> /etc 这类条目能绕过
    // isWithin 检查（字符串层面看着在目录内，实际指向外面）。
    final base = await destDir.resolveSymbolicLinks();

    for (final file in archive) {
      final name = file.name.replaceAll('\\', '/');
      // 绝对路径、盘符、上级目录一律跳过
      if (name.startsWith('/') || name.contains('..')) continue;
      if (RegExp(r'^[A-Za-z]:').hasMatch(name)) continue;

      final outPath = p.normalize(p.join(dest, name));
      if (!p.isWithin(base, outPath)) continue;

      if (file.isFile) {
        final out = File(outPath);
        final parent = out.parent;
        if (!await parent.exists()) {
          await parent.create(recursive: true);
        }
        final content = file.content;
        if (content is List<int>) {
          await out.writeAsBytes(Uint8List.fromList(content));
        }
      } else {
        final dir = Directory(outPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }
    }
  }

  /// 在解压目录里找主程序。优先 ben_browser.exe，否则挑体积最大的 exe。
  ///
  /// 全程用异步 IO：之前用 listSync / lengthSync 会在 UI 线程上做
  /// 递归目录遍历 + 大量 stat，包大时明显掉帧。
  Future<String?> _findExe(Directory pkg) async {
    if (!await pkg.exists()) return null;

    final files = await pkg
        .list(recursive: true)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.exe'))
        .toList();
    if (files.isEmpty) return null;

    for (final f in files) {
      if (p.basenameWithoutExtension(f.path).toLowerCase() == 'ben_browser') {
        return f.path;
      }
    }

    // 按体积取最大的（主程序通常远大于依赖 dll）
    var best = files.first;
    var bestSize = await best.length();
    for (final f in files.skip(1)) {
      final size = await f.length();
      if (size > bestSize) {
        best = f;
        bestSize = size;
      }
    }
    return best.path;
  }

  /// 生成替换脚本：等进程退出 → 拷文件 → 重启 → 收尾。
  ///
  /// 用 robocopy 是因为它对"部分文件被占用"的容错更好；返回码 ≥8 才算真失败，
  /// 此时回退到 xcopy。两条都走不通时日志会记下来，方便排查。
  /// 把路径烧进脚本前先做一次「危险字符」检查。
  ///
  /// 路径里若出现引号、&、|、^ 等字符，会破坏 set "VAR=..." 的结构，
  /// 轻则变量值截断，重则被 cmd 当成命令分隔符执行。
  /// 这里直接拒绝，宁可不更新也不能拼出一个行为不确定的脚本。
  static void _assertSafeForBatch(String label, String value) {
    if (RegExp(r'[&|^<>"]').hasMatch(value)) {
      throw StateError('$label 含有批处理危险字符，无法安全更新：$value');
    }
  }

  String _buildScript({
    required String pid,
    required String src,
    required String dst,
    required String exe,
    required String log,
    required String tmpRoot,
  }) {
    for (final entry in <String, String>{
      'SRC': src,
      'DST': dst,
      'EXE': exe,
      'LOG': log,
      'TMPROOT': tmpRoot,
    }.entries) {
      _assertSafeForBatch(entry.key, entry.value);
    }
    return '@echo off\r\n'
        'setlocal\r\n'
        'set "PID=$pid"\r\n'
        'set "SRC=$src"\r\n'
        'set "DST=$dst"\r\n'
        'set "EXE=$exe"\r\n'
        'set "LOG=$log"\r\n'
        'set "TMPROOT=$tmpRoot"\r\n'
        '\r\n'
        'echo [%date% %time%] updater start, waiting for pid %PID% > "%LOG%"\r\n'
        '\r\n'
        ':WAIT\r\n'
        'tasklist /FI "PID eq %PID%" /NH 2>nul | findstr /I "%PID%" >nul\r\n'
        'if not errorlevel 1 (\r\n'
        '  timeout /t 1 /nobreak >nul\r\n'
        '  goto WAIT\r\n'
        ')\r\n'
        '\r\n'
        'timeout /t 2 /nobreak >nul\r\n'
        '\r\n'
        'echo [%date% %time%] copying %SRC% to %DST% >> "%LOG%"\r\n'
        'robocopy "%SRC%" "%DST%" /E /IS /IT /NFL /NDL /NJH /NJS /NC /NS /NP\r\n'
        'if errorlevel 8 (\r\n'
        '  echo [%date% %time%] robocopy failed, fallback xcopy >> "%LOG%"\r\n'
        '  xcopy "%SRC%\\*" "%DST%" /Y /E /I /Q >> "%LOG%" 2>&1\r\n'
        ')\r\n'
        '\r\n'
        'echo [%date% %time%] restarting %EXE% >> "%LOG%"\r\n'
        'start "" "%EXE%"\r\n'
        '\r\n'
        'echo [%date% %time%] cleanup >> "%LOG%"\r\n'
        // 先把日志留一份在安装目录，方便事后排查「更新没生效」这类问题；
        // 失败了也无所谓（>nul 2>&1），不能因为它挡住清理。
        'copy /Y "%LOG%" "%DST%\\update-last.log" >nul 2>&1\r\n'
        // 再删整个临时根目录（含 update.zip），而不是只删解压出的 pkg。
        // 注意：rmdir 必须是**最后一条** —— cmd 是逐行读取 bat 的，
        // 把正在执行的 bat 自己删掉后再读下一行会出错，所以省掉末尾的
        // endlocal（脚本结束进程即退出，它没有意义）。
        'rmdir /S /Q "%TMPROOT%" 2>nul\r\n';
  }
}
