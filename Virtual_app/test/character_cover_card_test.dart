import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/views/common/character_cover_card.dart';

/// 封面卡简介预处理规则
///
/// 封面只有 3 行高度，「姓名：晓夜」这种身份字段行会把它变成简历表格；
/// 多行片段则会把版面浪费在换行上。这两条规则必须钉死。
void main() {
  group('coverSummaryOf', () {
    test('剔除首行身份字段行', () {
      const raw = '姓名：晓夜\n'
          '她把最后一盒关东煮留给常来的夜班司机，然后开始擦柜台。';

      expect(coverSummaryOf(raw), '她把最后一盒关东煮留给常来的夜班司机，然后开始擦柜台。');
    });

    test('各类字段标签一视同仁（代号 / 型号 / 本名）', () {
      expect(coverSummaryOf('代号：星尘（Stardust）\n长发下降 ratio 0.5。'),
          '长发下降 ratio 0.5。');
      expect(coverSummaryOf('型号：Aurora-Ⅶ\n她的投影比上次淡了 3%。'),
          '她的投影比上次淡了 3%。');
      expect(coverSummaryOf('本名：喵子\n一双猫耳猛地竖起来。'), '一双猫耳猛地竖起来。');
    });

    test('多行片段折叠为单行，不在封面浪费换行', () {
      const raw = '第一段内容。\n\n第二段内容。\n第三段内容。';

      final result = coverSummaryOf(raw);
      expect(result, '第一段内容。 第二段内容。 第三段内容。');
      expect(result.contains('\n'), isFalse);
    });

    test('普通长句不因含冒号被误伤', () {
      const raw = '这件事很重要：她从不记得顾客的脸，只记得他们买的烟。';

      expect(coverSummaryOf(raw), raw);
    });

    test('真实多行角色卡：连续的元信息字段行全部跳过，取最长叙述段落', () {
      // 种子角色（晓夜）的真实结构：连着 6 行「字段名：值」
      const raw = '姓名：晓夜\n'
          '年龄：24\n'
          '身份：24 小时便利店「夜灯」的夜班店员（22:00 - 06:00）\n'
          '外貌：及肩黑发，挽成松散的低马尾，常年戴着店里发的藏青色围裙\n'
          '背景：本地人，大学念的食品营养，毕业后没去考编也没接家里的安排，'
          '一个人在城里住了三年，她把夜班当作一种庇护。';

      final result = coverSummaryOf(raw);
      expect(result, startsWith('本地人，大学念的食品营养'));
      // 元信息一个字都不许漏出来
      expect(result, isNot(contains('姓名')));
      expect(result, isNot(contains('年龄')));
      expect(result, isNot(contains('背景')));
      expect(result.contains('\n'), isFalse);
    });

    test('空描述与纯元信息都收敛为空串', () {
      expect(coverSummaryOf(''), '');
      expect(coverSummaryOf('   \n  '), '');
      // 只有一行身份信息时，卡片不展示简介而不是显示「姓名：晓夜」
      expect(coverSummaryOf('姓名：晓夜'), '');
      expect(coverSummaryOf('姓名：晓夜\n年龄：24\n身份：夜班店员'), '');
    });
  });
}
