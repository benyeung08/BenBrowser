import '../core/constants.dart';

/// 地址栏输入解析：域名直达、URL 直通、其余走搜索
class UrlUtils {
  UrlUtils._();

  static final _schemeRe = RegExp(r'^[a-zA-Z][a-zA-Z\d+\-.]*://');
  static final _domainRe = RegExp(
    r'^[\w\-]+(\.[\w\-]+)+(:\d+)?([/?#].*)?$',
  );

  /// 把用户输入解析成可以直接加载的 Uri
  static Uri resolve(String input, {SearchEngine? engine}) {
    final text = input.trim();
    final e = engine ?? SearchEngine.bing;
    if (text.isEmpty) return Uri.parse(AppConstants.newTabUrl);

    if (_schemeRe.hasMatch(text)) {
      return Uri.tryParse(text) ?? Uri.parse(searchUrl(text, e));
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
