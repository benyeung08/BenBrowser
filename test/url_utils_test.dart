import 'package:flutter_test/flutter_test.dart';
import 'package:nimbus_browser/core/constants.dart';
import 'package:nimbus_browser/core/url_utils.dart';

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
