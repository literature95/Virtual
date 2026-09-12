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

  /// 统计字段（用户主页 / 关注列表可能携带，缺省为 0 / false）
  final int postCount;
  final int followerCount;
  final bool isFollowing;

  Creator({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.postCount = 0,
    this.followerCount = 0,
    this.isFollowing = false,
  });

  factory Creator.fromJson(Map<String, dynamic> j) => Creator(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? '匿名用户',
        avatarUrl: j['avatarUrl']?.toString(),
        bio: j['bio']?.toString(),
        postCount: (j['postCount'] as num?)?.toInt() ?? 0,
        followerCount: (j['followerCount'] as num?)?.toInt() ?? 0,
        isFollowing: j['isFollowing'] as bool? ?? false,
      );
}

/// 帖子类型
enum PostType {
  /// 用户发布的角色卡宣传
  characterCard,

  /// 对话炫耀卡片（截取一段对话分享）
  conversationShowcase,

  /// 官方公告 / 活动
  announcement,

  /// 普通文字动态（后端 community_posts.type = 'text'）
  text,
}

/// 后端 type 字段 → App 枚举
///
/// 后端取值：'text' / 'character_card' / 'conversation'（无 'announcement' 来源，
/// 该枚举值仅作兼容保留，目前不会由接口产出）。
extension PostTypeX on PostType {
  static PostType fromApi(String? s) {
    switch (s) {
      case 'character_card':
        return PostType.characterCard;
      case 'conversation':
        return PostType.conversationShowcase;
      case 'announcement':
        return PostType.announcement;
      default:
        return PostType.text;
    }
  }
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

  /// 当前登录用户是否已点赞（来自后端 likedByMe）
  final bool likedByMe;

  /// 当前登录用户是否已关注作者（来自后端 isFollowingAuthor，仅详情接口产出）
  final bool isFollowingAuthor;

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
    this.likedByMe = false,
    this.isFollowingAuthor = false,
    this.timeAgo = '',
  });

  /// 后端 JSON → 模型。
  ///
  /// 接口字段见 Virtual_background/routes/api/posts/index.dart 的 _postJson：
  /// author{id,name,avatarUrl}、tags/dialogue 为 JSON 数组、likes/likedByMe 由联表聚合。
  factory CommunityPost.fromJson(Map<String, dynamic> j) {
    final author = (j['author'] as Map?)?.cast<String, dynamic>() ?? {};
    final tags = (j['tags'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final dialogue = (j['dialogue'] as List?)
        ?.map((e) => DialogueLine.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return CommunityPost(
      id: j['id'].toString(),
      type: PostTypeX.fromApi(j['type']?.toString()),
      author: Creator.fromJson(author),
      title: j['title']?.toString() ?? '',
      content: j['content']?.toString() ?? '',
      characterId: j['characterId']?.toString(),
      dialogue: dialogue,
      tags: tags,
      community: j['community']?.toString() ?? '综合',
      likes: (j['likes'] as num?)?.toInt() ?? 0,
      comments: (j['comments'] as num?)?.toInt() ?? 0,
      shares: (j['shares'] as num?)?.toInt() ?? 0,
      likedByMe: j['likedByMe'] as bool? ?? false,
      isFollowingAuthor: j['isFollowingAuthor'] as bool? ?? false,
      timeAgo: timeAgoFrom(DateTime.tryParse(j['createdAt']?.toString() ?? '')),
    );
  }

  /// 返回点赞状态更新后的副本（乐观更新用）
  CommunityPost copyWithLiked(bool liked, int likes) => CommunityPost(
        id: id,
        type: type,
        author: author,
        title: title,
        content: content,
        imageUrl: imageUrl,
        characterId: characterId,
        characterName: characterName,
        dialogue: dialogue,
        tags: tags,
        community: community,
        likes: likes,
        comments: comments,
        shares: shares,
        likedByMe: liked,
        isFollowingAuthor: isFollowingAuthor,
        timeAgo: timeAgo,
      );

  /// 通用副本（更新 comments / isFollowingAuthor 等字段，乐观更新用）
  CommunityPost copyWith({
    bool? likedByMe,
    int? likes,
    int? comments,
    bool? isFollowingAuthor,
  }) =>
      CommunityPost(
        id: id,
        type: type,
        author: author,
        title: title,
        content: content,
        imageUrl: imageUrl,
        characterId: characterId,
        characterName: characterName,
        dialogue: dialogue,
        tags: tags,
        community: community,
        likes: likes ?? this.likes,
        comments: comments ?? this.comments,
        shares: shares,
        likedByMe: likedByMe ?? this.likedByMe,
        isFollowingAuthor: isFollowingAuthor ?? this.isFollowingAuthor,
        timeAgo: timeAgo,
      );
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

  factory DialogueLine.fromJson(Map<String, dynamic> j) => DialogueLine(
        isCharacter: j['isCharacter'] as bool? ?? false,
        name: j['name']?.toString() ?? '',
        text: j['text']?.toString() ?? '',
      );
}

/// 由发布时间计算相对描述（"刚刚 / x分钟前 / x小时前 / x天前"）
String timeAgoFrom(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 30) return '${diff.inDays}天前';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}个月前';
  return '${(diff.inDays / 365).floor()}年前';
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

// ── 以下为客户端静态配置（社区分类过滤项，非假帖子数据）──
// 帖子内容本身全部来自后端 /api/posts（社区_posts 表），不再使用本地假数据。

/// 推荐 Tab 的社区分类过滤项（横滑 chips）。
/// 仅作为过滤维度（点击传入 ?community=），不承载任何假帖子。
final communityCategories = <CommunityTag>[
  CommunityTag(
      name: '综合', icon: Icons.grid_view_rounded, color: TavoColors.violet),
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

/// 评论（动态详情页，与账号 / 帖子联动）
class Comment {
  final String id;
  final String postId;
  final Creator author;
  final String content;
  final DateTime? createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.content,
    this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'].toString(),
        postId: j['postId']?.toString() ?? '',
        author: Creator.fromJson(
          (j['author'] as Map?)?.cast<String, dynamic>() ?? {},
        ),
        content: j['content']?.toString() ?? '',
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
      );

  String get timeAgo => timeAgoFrom(createdAt);
}

/// 用户主页（点击头像进入，数据来自 /api/users/[id]）
class UserProfile {
  final String id;
  final String name;
  final String? nickname;
  final String? avatarUrl;
  final String? bio;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final bool isFollowing;
  final List<CommunityPost> posts;

  UserProfile({
    required this.id,
    required this.name,
    this.nickname,
    this.avatarUrl,
    this.bio,
    this.postCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.posts = const [],
  });

  UserProfile copyWith({
    String? name,
    String? nickname,
    String? avatarUrl,
    String? bio,
    int? postCount,
    int? followerCount,
    int? followingCount,
    bool? isFollowing,
    List<CommunityPost>? posts,
  }) =>
      UserProfile(
        id: id,
        name: name ?? this.name,
        nickname: nickname ?? this.nickname,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        postCount: postCount ?? this.postCount,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount ?? this.followingCount,
        isFollowing: isFollowing ?? this.isFollowing,
        posts: posts ?? this.posts,
      );

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'].toString(),
        name: j['name']?.toString() ?? '匿名用户',
        nickname: j['nickname']?.toString(),
        avatarUrl: j['avatarUrl']?.toString(),
        bio: j['bio']?.toString(),
        postCount: (j['postCount'] as num?)?.toInt() ?? 0,
        followerCount: (j['followerCount'] as num?)?.toInt() ?? 0,
        followingCount: (j['followingCount'] as num?)?.toInt() ?? 0,
        isFollowing: j['isFollowing'] as bool? ?? false,
        posts: ((j['posts'] as List?) ?? [])
            .map((e) =>
                CommunityPost.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
