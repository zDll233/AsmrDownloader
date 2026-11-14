import 'package:asmr_downloader/common/const.dart';
import 'package:asmr_downloader/services/ui/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseHexColor', () {
    test('解析带 # 前缀的六位十六进制', () {
      expect(parseHexColor('#9C27B0'), const Color(0xFF9C27B0));
    });

    test('不带 # 也能解析', () {
      expect(parseHexColor('9C27B0'), const Color(0xFF9C27B0));
    });

    test('大小写不敏感, 允许首尾空白', () {
      expect(parseHexColor('  #9c27b0  '), const Color(0xFF9C27B0));
    });

    test('非法输入返回 null', () {
      expect(parseHexColor(''), isNull);
      expect(parseHexColor('#FFF'), isNull);
      expect(parseHexColor('#GGGGGG'), isNull);
      expect(parseHexColor('#1234567'), isNull);
    });
  });

  group('colorToHex', () {
    test('转成 #RRGGBB (不含 alpha)', () {
      expect(colorToHex(const Color(0xFF9C27B0)), '#9C27B0');
    });

    test('与 parseHexColor 互逆', () {
      const hex = '#00BCD4';
      expect(colorToHex(parseHexColor(hex)!), hex);
    });
  });

  group('resolveThemeSeedHex', () {
    test('缺省返回默认紫色', () {
      expect(resolveThemeSeedHex({}), kDefaultThemeSeedHex);
    });

    test('配置为空串时也回退默认', () {
      expect(resolveThemeSeedHex({'themeSeedColor': ''}), kDefaultThemeSeedHex);
    });

    test('读取用户设置的颜色', () {
      expect(
        resolveThemeSeedHex({'themeSeedColor': '#00BCD4'}),
        '#00BCD4',
      );
    });

    test('默认值是紫色 (与本次改动的约定一致)', () {
      expect(kDefaultThemeSeedHex, '#9C27B0');
    });
  });

  group('resolveWindowEffect', () {
    test('缺省为亚克力', () {
      expect(resolveWindowEffect({}), WINDOW_EFFECT_ACRYLIC);
    });

    test('读取用户设置', () {
      expect(
        resolveWindowEffect({'windowEffect': WINDOW_EFFECT_OPAQUE}),
        WINDOW_EFFECT_OPAQUE,
      );
    });
  });

  group('窗口记忆默认值 (照搬 Again)', () {
    test('记住位置默认关闭, 记住大小默认开启', () {
      expect(kDefaultRememberWindowPos, isFalse);
      expect(kDefaultRememberWindowSize, isTrue);
    });
  });
}
