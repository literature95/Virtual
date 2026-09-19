import 'dart:convert';

import 'package:test/test.dart';
import 'package:virtual_background/community_mapper.dart';

/// 构造一行「数据库行」形态的数据（列名与 SQL 别名一致）
Map<String, dynamic> row({
  Object? id = 'p-1',
  Object? userId = 'u-1',
  Object? type = 'text',
  Object? title = '标题',
  Object? content = '正文',
  Object? community = '综合',
  Object? tags,
  Object? characterId,
  Object? dialogue,
  Object? location,
  Object? locationLat,
  Object? locationLng,
  DateTime? createdAt,
  Object? authorName = '作者',
  Object? authorAvatar = '/a.png',
  Object? likes = 0,
  Object? likedByMe = false,
  Object? comments = 0,
  Object? isFollowingAuthor,
}) =>
    {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'content': content,
      'community': community,
      'tags': tags,
      'character_id': characterId,
      'dialogue': dialogue,
      'location': location,
      'location_lat': locationLat,
      'location_lng': locationLng,
      'created_at': createdAt ?? DateTime.utc(2026, 1, 1, 12),
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'likes': likes,
      'liked_by_me': likedByMe,
      'comments': comments,
      if (isFollowingAuthor != null) 'is_following_author': isFollowingAuthor,
    };

void main() {
  group('postJsonFromRow 基础映射', () {
    test('标量字段按接口约定改名并透传', () {
      final j = postJsonFromRow(row(
        id: 'p-9',
        type: 'character_card',
        title: 'T',
        content: 'C',
        community: '治愈',
        likes: 12,
        likedByMe: true,
        comments: 5,
      ));

      expect(j['id'], 'p-9');
      expect(j['type'], 'character_card');
      expect(j['title'], 'T');
      expect(j['content'], 'C');
      expect(j['community'], '治愈');
      expect(j['likes'], 12);
      expect(j['likedByMe'], isTrue);
      // 【回归】列表页评论数曾因某一处漏了聚合列而恒为 0
      expect(j['comments'], 5);
      expect(j['shares'], 0);
    });

    test('id / characterId 统一转字符串（数据库可能给非 String）', () {
      final j = postJsonFromRow(row(id: 42, characterId: 7));
      expect(j['id'], '42');
      expect(j['characterId'], '7');
    });

    test('characterId 为 null 时保持 null（不写成字符串 "null"）', () {
      final j = postJsonFromRow(row(characterId: null));
      expect(j['characterId'], isNull);
    });

    test('createdAt 转 ISO8601 字符串', () {
      final j = postJsonFromRow(row(createdAt: DateTime.utc(2026, 3, 4, 5, 6)));
      expect(j['createdAt'], DateTime.utc(2026, 3, 4, 5, 6).toIso8601String());
    });

    test('author 子对象由 JOIN 列组成', () {
      final j = postJsonFromRow(row(authorName: '张三', authorAvatar: '/z.png'));
      final a = j['author'] as Map;
      expect(a['id'], 'u-1');
      expect(a['name'], '张三');
      expect(a['avatarUrl'], '/z.png');
    });
  });

  group('postJsonFromRow JSONB 列解码', () {
    test('tags / dialogue 以 JSON 字符串形态存储时被解码为数组', () {
      final j = postJsonFromRow(row(
        tags: jsonEncode(['Fantasy', 'OC']),
        dialogue: jsonEncode([
          {'isCharacter': true, 'name': '角色', 'text': '你好'},
        ]),
      ));

      expect(j['tags'], ['Fantasy', 'OC']);
      final d = (j['dialogue'] as List).cast<Map<String, dynamic>>();
      expect(d.first['text'], '你好');
    });

    test('tags / dialogue 已是 List 时原样返回', () {
      final j = postJsonFromRow(row(
        tags: ['a'],
        dialogue: [
          {'isCharacter': false, 'name': '我', 'text': 'x'},
        ],
      ));
      expect(j['tags'], ['a']);
      expect(j['dialogue'], hasLength(1));
    });

    test('tags / dialogue 为 null 时回落空数组（App 端期望 List）', () {
      final j = postJsonFromRow(row(tags: null, dialogue: null));
      expect(j['tags'], isEmpty);
      expect(j['dialogue'], isEmpty);
    });
  });

  group('postJsonFromRow isFollowingAuthor 三态', () {
    test('详情接口：行内含该列时采用行内值', () {
      final t = postJsonFromRow(row(isFollowingAuthor: true));
      final f = postJsonFromRow(row(isFollowingAuthor: false));
      expect(t['isFollowingAuthor'], isTrue);
      expect(f['isFollowingAuthor'], isFalse);
    });

    test('列表接口：行内无该列 → 默认 false（不返回 null）', () {
      final j = postJsonFromRow(row());
      expect(j['isFollowingAuthor'], isFalse);
    });

    test('显式传入优先于行内值', () {
      final j = postJsonFromRow(row(isFollowingAuthor: false),
          isFollowingAuthor: true);
      expect(j['isFollowingAuthor'], isTrue);
    });
  });

  group('postJsonFromRow 用户主页覆盖作者', () {
    test('传入 authorName / authorAvatar 时覆盖（用户行未 JOIN 作者列）', () {
      // 复现用户主页的真实行：没有 author_name / author_avatar 列
      final r = row(authorName: null, authorAvatar: null)
        ..remove('author_name')
        ..remove('author_avatar');

      final j = postJsonFromRow(r,
          authorName: '主页主人', authorAvatar: '/me.png');
      final a = j['author'] as Map;
      expect(a['name'], '主页主人');
      expect(a['avatarUrl'], '/me.png');
      expect(a['id'], 'u-1');
    });

    test('主页主人头像为 null 时保持 null', () {
      final r = row(authorName: null, authorAvatar: null)
        ..remove('author_name')
        ..remove('author_avatar');

      final j = postJsonFromRow(r, authorName: '主页主人');
      expect((j['author'] as Map)['avatarUrl'], isNull);
    });
  });

  group('postJsonFromRow 输出契约', () {
    test('三个端点共用同一超集键集合（App 解析零改动的前提）', () {
      final keys = postJsonFromRow(row()).keys.toSet();
      expect(
        keys,
        containsAll(<String>[
          'id', 'type', 'title', 'content', 'community', 'tags',
          'characterId', 'dialogue', 'createdAt', 'author',
          'likes', 'likedByMe', 'comments', 'shares', 'isFollowingAuthor',
          // 高德发动态定位
          'location', 'locationLat', 'locationLng',
        ]),
      );
    });

    test('location 三列透传；空位为 null 不抛异常', () {
      final j = postJsonFromRow(row(
        location: '北京市·朝阳区',
        locationLat: 39.9,
        locationLng: 116.4,
      ));
      expect(j['location'], '北京市·朝阳区');
      expect(j['locationLat'], 39.9);
      expect(j['locationLng'], 116.4);

      final empty = postJsonFromRow(row());
      expect(empty['location'], isNull);
      expect(empty['locationLat'], isNull);
      expect(empty['locationLng'], isNull);
    });

    test('结果可被 jsonEncode（无不可序列化类型）', () {
      final j = postJsonFromRow(row(
        tags: jsonEncode(['t']),
        dialogue: jsonEncode([
          {'isCharacter': true, 'name': 'n', 'text': 'x'},
        ]),
        isFollowingAuthor: true,
      ));
      expect(() => jsonEncode(j), returnsNormally);
    });
  });
}
