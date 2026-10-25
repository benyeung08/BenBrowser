import 'package:ben_browser/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersion', () {
    test('新版本大于旧版本', () {
      expect(compareVersion('0.2.0', '0.1.0'), greaterThan(0));
      expect(compareVersion('1.0.0', '0.9.9'), greaterThan(0));
      expect(compareVersion('0.1.10', '0.1.9'), greaterThan(0));
    });

    test('旧版本小于新版本', () {
      expect(compareVersion('0.1.0', '0.2.0'), lessThan(0));
    });

    test('相同版本相等', () {
      expect(compareVersion('0.1.0', '0.1.0'), 0);
      expect(compareVersion('1.2', '1.2.0'), 0, reason: '位数不齐视为相等');
    });

    test('容忍 v 前缀与 build 号', () {
      expect(compareVersion('v0.2.0', '0.1.0'), greaterThan(0));
      expect(compareVersion('0.1.0+1', '0.1.0+9'), 0);
      expect(compareVersion('v1.0.0+2', '1.0.0'), 0);
    });

    test('非法片段按 0 处理，不抛异常', () {
      expect(() => compareVersion('abc', '0.1.0'), returnsNormally);
    });
  });
}
