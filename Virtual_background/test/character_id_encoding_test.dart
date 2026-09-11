import 'package:test/test.dart';
import 'package:virtual_background/character_card_mapper.dart';
import 'package:virtual_background/path_param.dart';

/// 中文（非 ASCII）角色 id 的两个缺陷回归测试（2026-09-11 实测发现）：
///
/// A. dart_frog 用 `request.url.path` 捕获路由参数且**不解码**；Dart 的 `Uri.path`
///    只对 ASCII 安全字符的转义做归一化解码，对 `%E5%B8%8C…`（汉字）保留百分号编码
///    ⇒ 详情/导出端点用中文 id 恒 404。
/// B. `slugify` 故意保留汉字，而文件名净化会把汉字全部换成 `_`
///    ⇒ 不同中文名坍缩到同一立绘文件名，同版本互相覆盖。
void main() {
  group('A. decodePathParam：还原 dart_frog 未解码的路径参数', () {
    test('复现根因：Uri.path 对汉字保留百分号编码，解码后才等于原名', () {
      const name = '希露妲';
      final encoded = Uri.encodeComponent(name);
      expect(encoded, '%E5%B8%8C%E9%9C%B2%E5%A6%B2');

      // dart_frog 拿 request.url.path 匹配并捕获 [id]，拿到的是这个字面量
      final uri = Uri.parse('http://x/api/characters/$encoded');
      final captured = uri.path.split('/').last;
      expect(
        captured,
        encoded,
        reason: '汉字转义不会被 Uri.path 归一化，捕获到的就是 %XX 字面量',
      );
      expect(captured, isNot(name), reason: '这正是 404 的原因');

      // 修复：解码后与库中 id 相等
      expect(decodePathParam(captured), name);
    });

    test('对照：ASCII 安全转义会被 Uri.path 自身归一化（所以旧用例不报错）', () {
      final uri = Uri.parse('http://x/api/characters/%63har-001');
      expect(uri.path.split('/').last, 'char-001');
      expect(decodePathParam('char-001'), 'char-001');
    });

    test('ASCII / 已解码 / 空串 均保持原样', () {
      expect(decodePathParam('char-001'), 'char-001');
      expect(decodePathParam('cricket'), 'cricket');
      expect(decodePathParam(''), '');
    });

    test('非法转义退回原串，不抛异常（避免畸形请求打成 500）', () {
      expect(decodePathParam('%'), '%');
      expect(decodePathParam('%zz'), '%zz');
      expect(decodePathParam('a%'), 'a%');
    });

    test('只解码一次：含字面量 % 的 id 不会过度解码', () {
      // slugify 会把 % 换成 -，故真实 id 不含 %；这里锁住语义防回归。
      expect(decodePathParam('100%25'), '100%');
    });
  });

  group('B. sanitizeIdForFile：中文 id 不再坍缩成同名', () {
    test('不同中文 id 产出不同文件名（修复覆盖缺陷）', () {
      final a = CharacterCardMapper.sanitizeIdForFile('希露妲');
      final b = CharacterCardMapper.sanitizeIdForFile('星尘');
      final c = CharacterCardMapper.sanitizeIdForFile('墨书');
      expect(a, isNot(b));
      expect(b, isNot(c));
      expect(a, isNot(c));
      // 修复前这三者都会是 '___'，这里显式锁住"不再相等"
      expect({a, b, c}.length, 3);
    });

    test('立绘完整文件名对中文 id 也唯一（同版本不互相覆盖）', () {
      String avatarName(String id) =>
          'char-${CharacterCardMapper.sanitizeIdForFile(id)}-'
          '${CharacterCardMapper.sanitizeFilename('1.0')}.png';
      final names = ['希露妲', '星尘', '墨书', '喵子']
          .map(avatarName)
          .toSet();
      expect(names.length, 4);
    });

    test('ASCII 合法 id 保持原样，不加哈希（不破坏既有文件名/URL）', () {
      expect(CharacterCardMapper.sanitizeIdForFile('char-001'), 'char-001');
      expect(CharacterCardMapper.sanitizeIdForFile('cricket'), 'cricket');
    });

    test('产出仍是跨平台安全的 ASCII 文件名片段', () {
      for (final id in ['希露妲', '星尘', '墨书', '喵子', 'Aurora']) {
        final safe = CharacterCardMapper.sanitizeIdForFile(id);
        expect(
          RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(safe),
          isTrue,
          reason: '$id -> $safe 必须只含 [a-zA-Z0-9_-]',
        );
      }
    });

    test('FNV-1a 确定且稳定（文件名可复现，跨进程一致）', () {
      expect(
        CharacterCardMapper.fnv1a8('希露妲'),
        CharacterCardMapper.fnv1a8('希露妲'),
      );
      expect(CharacterCardMapper.fnv1a8('希露妲').length, 8);
      expect(CharacterCardMapper.fnv1a8('星尘'), isNot(CharacterCardMapper.fnv1a8('希露妲')));
      // 已知值锁定：FNV-1a 32 位"空串"偏移基准
      expect(CharacterCardMapper.fnv1a8(''), '811c9dc5');
    });

    test('sanitizeFilename 本身语义不变（仅做字符替换）', () {
      expect(CharacterCardMapper.sanitizeFilename('1.0'), '1_0');
      expect(CharacterCardMapper.sanitizeFilename('main'), 'main');
      expect(CharacterCardMapper.sanitizeFilename('希露妲'), '___');
    });
  });
}
