import 'package:flutter/material.dart';

import '../theme/tavo_brand.dart';

/// 社区动态数据模型
///
/// 发现页社区信息流使用：用户发布的角色卡宣传、对话炫耀卡片、官方公告。
/// 第一版使用 Mock 假数据，后续接后端 API 时替换数据来源即可。

/// 创作者（被关注的用户）
class Creator {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? bio;

  Creator({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.bio,
  });
}

/// 帖子类型
enum PostType {
  /// 用户发布的角色卡宣传
  characterCard,

  /// 对话炫耀卡片（截取一段对话分享）
  conversationShowcase,

  /// 官方公告 / 活动
  announcement,
}

/// 社区动态帖子
class CommunityPost {
  final String id;
  final PostType type;
  final Creator author;

  /// 帖子标题
  final String title;

  /// 帖子正文（动态描述）
  final String content;

  /// 配图 URL（角色卡封面 / 对话截图 / 公告横幅）
  final String? imageUrl;

  /// 关联角色卡 ID（characterCard 类型时非空，点击可跳转导入）
  final String? characterId;

  /// 关联角色名（展示用）
  final String? characterName;

  /// 对话片段（conversationShowcase 类型时使用）
  final List<DialogueLine>? dialogue;

  /// 标签
  final List<String> tags;

  /// 社区分类（推荐 tab 按此分组）
  final String community;

  /// 互动数据
  final int likes;
  final int comments;
  final int shares;

  /// 发布时间（相对描述，如 "2小时前"）
  final String timeAgo;

  const CommunityPost({
    required this.id,
    required this.type,
    required this.author,
    required this.title,
    this.content = '',
    this.imageUrl,
    this.characterId,
    this.characterName,
    this.dialogue,
    this.tags = const [],
    this.community = '综合',
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.timeAgo = '',
  });
}

/// 对话片段中的一行
class DialogueLine {
  /// true = 角色说话，false = 用户说话
  final bool isCharacter;
  final String name;
  final String text;

  const DialogueLine({
    required this.isCharacter,
    required this.name,
    required this.text,
  });
}

/// 社区分类标签
class CommunityTag {
  final String name;
  final IconData icon;
  final Color color;

  const CommunityTag({
    required this.name,
    required this.icon,
    required this.color,
  });
}

// ── 以下为 Mock 假数据，后续替换为后端 API ──

/// Mock 关注列表
final mockFollowing = <Creator>[
  Creator(id: 'u1', name: '夜行者', bio: '奇幻角色创作者'),
  Creator(id: 'u2', name: '月下狐', bio: '治愈系故事作者'),
  Creator(id: 'u3', name: '工口魔王', bio: '冒险/战斗专家'),
  Creator(id: 'u4', name: '清茶淡饭', bio: '日常向角色'),
  Creator(id: 'u5', name: '星海漫游', bio: '科幻/未来向'),
];

/// Mock 推荐社区分类
final mockCommunities = <CommunityTag>[
  CommunityTag(
      name: '治愈', icon: Icons.favorite_rounded, color: TavoColors.coral),
  CommunityTag(
      name: '冒险', icon: Icons.explore_rounded, color: TavoColors.amber),
  CommunityTag(name: '恋爱', icon: Icons.wc_rounded, color: TavoColors.violet),
  CommunityTag(
      name: '奇幻',
      icon: Icons.auto_awesome_rounded,
      color: TavoColors.brandPurpleLight),
  CommunityTag(
      name: '科幻',
      icon: Icons.rocket_launch_rounded,
      color: TavoColors.cosmosGreen),
  CommunityTag(
      name: '日常', icon: Icons.coffee_rounded, color: TavoColors.brandOrange),
  CommunityTag(
      name: '战斗', icon: Icons.bolt_rounded, color: TavoColors.brandOrangeLight),
  CommunityTag(
      name: '悬疑',
      icon: Icons.search_rounded,
      color: TavoColors.textHighlightPurple),
];

/// Mock 关注 tab 信息流
final mockFollowingPosts = <CommunityPost>[
  CommunityPost(
    id: 'p1',
    type: PostType.characterCard,
    author: mockFollowing[0],
    title: '暗影刺客·零',
    content: '新角色上线！一位来自暗夜组织的顶级刺客，冷静而致命。拥有三套战斗预设和专属世界书。',
    imageUrl: null,
    characterId: 'cricket',
    characterName: 'Cricket',
    tags: ['冒险', '战斗', '奇幻'],
    community: '冒险',
    likes: 328,
    comments: 47,
    shares: 23,
    timeAgo: '2小时前',
  ),
  CommunityPost(
    id: 'p2',
    type: PostType.conversationShowcase,
    author: mockFollowing[1],
    title: '和月下狐的治愈日常',
    content: '今天她说了好温柔的话……',
    characterName: '月下狐',
    dialogue: const [
      DialogueLine(isCharacter: false, name: '我', text: '今天好累啊，什么都不想做。'),
      DialogueLine(
          isCharacter: true, name: '月下狐', text: '那就什么都不做吧。我陪你坐着，等到你想动为止。'),
      DialogueLine(isCharacter: false, name: '我', text: '……你会一直在这里吗？'),
      DialogueLine(isCharacter: true, name: '月下狐', text: '嗯，一直都在。'),
    ],
    tags: ['治愈', '日常'],
    community: '治愈',
    likes: 1204,
    comments: 89,
    shares: 66,
    timeAgo: '5小时前',
  ),
  CommunityPost(
    id: 'p3',
    type: PostType.characterCard,
    author: mockFollowing[2],
    title: '深渊魔女·莉莉丝',
    content: '耗时两周打造的角色卡，包含完整世界观、5个场景预设和20条世界书词条。快来体验和魔女的契约吧！',
    characterId: 'cricket',
    characterName: 'Cricket',
    tags: ['奇幻', '战斗'],
    community: '奇幻',
    likes: 562,
    comments: 73,
    shares: 41,
    timeAgo: '8小时前',
  ),
  CommunityPost(
    id: 'p4',
    type: PostType.conversationShowcase,
    author: mockFollowing[3],
    title: '咖啡店老板的早晨',
    content: '每天的对话都像在过日子，太真实了',
    characterName: '清茶',
    dialogue: const [
      DialogueLine(isCharacter: true, name: '清茶', text: '早安，今天还是老样子？美式加一份浓缩。'),
      DialogueLine(isCharacter: false, name: '我', text: '你记得真清楚。'),
      DialogueLine(
          isCharacter: true, name: '清茶', text: '常客的口味当然要记住。这是你的第五百杯了，今天免费。'),
    ],
    tags: ['日常', '治愈'],
    community: '日常',
    likes: 873,
    comments: 52,
    shares: 38,
    timeAgo: '12小时前',
  ),
];

/// Mock 推荐 tab 信息流
final mockRecommendPosts = <CommunityPost>[
  // 官方公告
  CommunityPost(
    id: 'r0',
    type: PostType.announcement,
    author: Creator(id: 'official', name: 'Virtual 官方', bio: '官方账号'),
    title: 'v1.2.0 更新：多角色群聊上线！',
    content: '本次更新带来多角色群聊功能，支持在一个对话中同时与多位角色互动。还优化了角色卡导入流程，修复了若干已知问题。',
    imageUrl: null,
    tags: ['更新公告', '新功能'],
    community: '综合',
    likes: 2048,
    comments: 156,
    shares: 234,
    timeAgo: '1天前',
  ),
  // 热门角色卡
  CommunityPost(
    id: 'r1',
    type: PostType.characterCard,
    author: mockFollowing[4],
    title: '星际旅人·Nova',
    content: '一位来自 3077 年的星际旅行者，拥有丰富的宇宙探索故事。附带完整科幻世界书和 3 套对话预设。',
    characterId: 'cricket',
    characterName: 'Cricket',
    tags: ['科幻', '冒险'],
    community: '科幻',
    likes: 1520,
    comments: 98,
    shares: 87,
    timeAgo: '3小时前',
  ),
  CommunityPost(
    id: 'r2',
    type: PostType.conversationShowcase,
    author: mockFollowing[0],
    title: '暗影刺客的告白',
    content: '没想到冷酷的刺客也有这样的一面……',
    characterName: '暗影刺客·零',
    dialogue: const [
      DialogueLine(isCharacter: false, name: '我', text: '你为什么要做刺客？'),
      DialogueLine(isCharacter: true, name: '暗影刺客·零', text: '……因为我只会这个。'),
      DialogueLine(
          isCharacter: true,
          name: '暗影刺客·零',
          text: '但如果可以重来，我想做花匠。种花的人，手上只有泥土的味道。'),
    ],
    tags: ['冒险', '战斗'],
    community: '冒险',
    likes: 2347,
    comments: 184,
    shares: 156,
    timeAgo: '6小时前',
  ),
  CommunityPost(
    id: 'r3',
    type: PostType.characterCard,
    author: mockFollowing[1],
    title: '温柔学姐·苏念',
    content: '一位会帮你补习、做便当、雨天递伞的完美学姐。治愈系角色卡，附带 3 个日常场景预设。',
    characterId: 'cricket',
    characterName: 'Cricket',
    tags: ['恋爱', '日常', '治愈'],
    community: '恋爱',
    likes: 3104,
    comments: 210,
    shares: 198,
    timeAgo: '10小时前',
  ),
  CommunityPost(
    id: 'r4',
    type: PostType.conversationShowcase,
    author: mockFollowing[4],
    title: '和 Nova 的星际日常',
    content: '3000 年的人类日常',
    characterName: 'Nova',
    dialogue: const [
      DialogueLine(
          isCharacter: true, name: 'Nova', text: '你知道吗，在 3077 年，咖啡已经是古董饮料了。'),
      DialogueLine(isCharacter: false, name: '我', text: '那你们喝什么？'),
      DialogueLine(
          isCharacter: true,
          name: 'Nova',
          text: '情绪。我们可以直接品尝情感的味道。和你聊天的时候……是甜的。'),
    ],
    tags: ['科幻'],
    community: '科幻',
    likes: 1876,
    comments: 143,
    shares: 92,
    timeAgo: '14小时前',
  ),
];
