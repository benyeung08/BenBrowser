import 'package:flutter_test/flutter_test.dart';
import 'package:ben_browser/core/constants.dart';
import 'package:ben_browser/core/url_utils.dart';

void main() {
  group('UrlUtils.resolve', () {
    test('裸域名自动补全 https', () {
      expect(
        UrlUtils.resolve('example.com').toString(),
        'https://example.com',
      );
    });

    test('带协议的输入保持原样', () {
      expect(
        UrlUtils.resolve('http://example.com/a?b=1').toString(),
        'http://example.com/a?b=1',
      );
    });

    test('非网址走搜索引擎', () {
      final uri = UrlUtils.resolve('flutter webview 浏览器');
      expect(uri.toString(), contains('bing.com'));
    });

    test('可切换搜索引擎', () {
      final uri = UrlUtils.resolve('flutter', engine: SearchEngine.baidu);
      expect(uri.toString(), contains('baidu.com'));
    });

    test('空输入落到新标签页', () {
      expect(
        UrlUtils.resolve('   ').toString(),
        AppConstants.newTabUrl,
      );
    });

    test('危险 scheme 不原样加载，退化为搜索', () {
      // file:// / content:// 能读到本地文件与媒体库，浏览器不该具备这个能力。
      // 它们必须退化成搜索，而不是被 WebView 直接打开。
      final file = UrlUtils.resolve('file:///etc/passwd');
      expect(file.toString(), contains('bing.com'));
      expect(file.scheme, isNot('file'));

      final content = UrlUtils.resolve('content://media/external/images/1');
      expect(content.scheme, isNot('content'));
    });

    test('isAllowedScheme 只放行白名单', () {
      expect(UrlUtils.isAllowedScheme(Uri.parse('https://a.com')), isTrue);
      expect(UrlUtils.isAllowedScheme(Uri.parse('http://a.com')), isTrue);
      expect(UrlUtils.isAllowedScheme(Uri.parse('about:blank')), isTrue);
      expect(UrlUtils.isAllowedScheme(Uri.parse('file:///tmp/x')), isFalse);
      expect(UrlUtils.isAllowedScheme(Uri.parse('content://x')), isFalse);
      expect(UrlUtils.isAllowedScheme(Uri.parse('javascript:alert(1)')),
          isFalse);
    });
  });

  group('UrlUtils.pretty', () {
    test('去掉协议与 www', () {
      expect(UrlUtils.pretty('https://www.example.com/x'), 'example.com/x');
    });

    test('识别安全协议', () {
      expect(UrlUtils.isSecure('https://a.com'), isTrue);
      expect(UrlUtils.isSecure('http://a.com'), isFalse);
    });
  });
}
