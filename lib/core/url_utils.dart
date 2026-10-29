import '../core/constants.dart';

/// 地址栏输入解析：域名直达、URL 直通、其余走搜索
class UrlUtils {
  UrlUtils._();

  static final _schemeRe = RegExp(r'^[a-zA-Z][a-zA-Z\d+\-.]*://');
  static final _domainRe = RegExp(
    r'^[\w\-]+(\.[\w\-]+)+(:\d+)?([/?#].*)?$',
  );

  /// 允许在 WebView 里加载的 scheme 白名单。
  ///
  /// 不做白名单的话，地址栏输入 `file:///etc/passwd` 或
  /// `content://media/...` 会直接把本地文件/媒体库读进页面——
  /// 浏览器不该有这个能力。
  /// Windows 上 `file://` 偶有用于打开本地 HTML，但风险大于收益，一并禁掉。
  static const Set<String> _allowedSchemes = <String>{
    'http',
    'https',
    'about',
  };

  /// 该 Uri 是否允许加载。
  /// 空 scheme（如 `about:blank`）视为安全。
  static bool isAllowedScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isEmpty) return true;
    return _allowedSchemes.contains(scheme);
  }

  /// 把用户输入解析成可以直接加载的 Uri。
  ///
  /// 非白名单 scheme 一律退回搜索，而不是照原样加载。
  static Uri resolve(String input, {SearchEngine? engine}) {
    final text = input.trim();
    final e = engine ?? SearchEngine.bing;
    if (text.isEmpty) return Uri.parse(AppConstants.newTabUrl);

    if (_schemeRe.hasMatch(text)) {
      final parsed = Uri.tryParse(text);
      if (parsed != null && isAllowedScheme(parsed)) return parsed;
      // 不安全的 scheme：退化成搜索，绝不原样加载
      return Uri.parse(searchUrl(text, e));
    }
    if (_domainRe.hasMatch(text)) {
      return Uri.parse('https://$text');
    }
    return Uri.parse(searchUrl(text, e));
  }

  /// 用搜索引擎拼查询地址
  static String searchUrl(String query, SearchEngine engine) =>
      engine.template.replaceFirst('{q}', Uri.encodeComponent(query));

  /// 展示用的精简地址（去掉协议与 www.）
  static String pretty(String url) {
    var s = url;
    if (s.startsWith('https://')) s = s.substring(8);
    if (s.startsWith('http://')) s = s.substring(7);
    if (s.startsWith('www.')) s = s.substring(4);
    if (s.length > 60) s = '${s.substring(0, 60)}…';
    return s;
  }

  static bool isSecure(String url) => url.startsWith('https://');

  /// 站点根地址（用于 favicon / 书签分组）
  static String? origin(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }
}
