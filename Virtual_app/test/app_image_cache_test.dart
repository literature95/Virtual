import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/services/app_image_cache.dart';

void main() {
  group('AppImageCache.keyFor', () {
    test('去掉首尾空白', () {
      expect(
        AppImageCache.keyFor('  https://host/a.jpg  '),
        'https://host/a.jpg',
      );
    });

    test('去掉 #fragment', () {
      expect(
        AppImageCache.keyFor('https://host/a.jpg#retry=2'),
        'https://host/a.jpg',
      );
    });

    test('同一原图不同 fragment 得到同一 key', () {
      expect(
        AppImageCache.keyFor('https://host/a.jpg'),
        AppImageCache.keyFor('https://host/a.jpg#x'),
      );
    });

    test('普通 URL 原样返回', () {
      expect(
        AppImageCache.keyFor('https://host/api/avatars/a.jpg'),
        'https://host/api/avatars/a.jpg',
      );
    });
  });

  group('AppImageCache.decodeWidthFor', () {
    test('按显示宽 × DPR 取整', () {
      // 180dp × 3.0 = 540
      expect(AppImageCache.decodeWidthFor(180, 3), 540);
      // 112dp × 2.75 = 308
      expect(AppImageCache.decodeWidthFor(112, 2.75), 308);
    });

    test('非法输入返回 null（解原图）', () {
      expect(AppImageCache.decodeWidthFor(0, 3), isNull);
      expect(AppImageCache.decodeWidthFor(-1, 3), isNull);
      expect(AppImageCache.decodeWidthFor(double.nan, 3), isNull);
      expect(AppImageCache.decodeWidthFor(double.infinity, 3), isNull);
      expect(AppImageCache.decodeWidthFor(180, 0), isNull);
      expect(AppImageCache.decodeWidthFor(180, double.nan), isNull);
    });

    test('超过上限时钳到 max', () {
      expect(AppImageCache.decodeWidthFor(4000, 2, max: 4096), 4096);
      expect(AppImageCache.decodeWidthFor(4000, 2, max: 2048), 2048);
    });

    test('结果非常小但仍为正数', () {
      expect(AppImageCache.decodeWidthFor(1, 1), 1);
    });
  });

  group('lookaheadIndices', () {
    test('从当前下标往后取 2 个（不含自身）', () {
      expect(lookaheadIndices(0, 10), [1, 2]);
      expect(lookaheadIndices(5, 10), [6, 7]);
    });

    test('末尾自动截断', () {
      expect(lookaheadIndices(8, 10), [9]);
      expect(lookaheadIndices(9, 10), isEmpty);
    });

    test('空列表 / 非法参数返回空', () {
      expect(lookaheadIndices(0, 0), isEmpty);
      expect(lookaheadIndices(-1, 5), [0, 1]);
      expect(lookaheadIndices(0, 5, lookahead: 0), isEmpty);
    });

    test('lookahead 可配置', () {
      expect(lookaheadIndices(0, 10, lookahead: 4), [1, 2, 3, 4]);
    });
  });
}
