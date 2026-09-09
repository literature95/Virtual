/// 首页轮播位
///
/// 运营 Banner，通常横向构图并关联一个角色卡；点击后走「导入 → 进入对话」，
/// 与首页封面卡同一条闭环。
class BannerItem {
  final String id;
  final String title;
  final String subtitle;

  /// 横版图片（推荐 16:9，与角色立绘原图一致）
  final String? imageUrl;

  /// 关联角色卡 ID —— 点击时按此 ID 拉详情导入
  final String? characterId;

  const BannerItem({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.imageUrl,
    this.characterId,
  });

  bool get canOpen => characterId != null && characterId!.isNotEmpty;

  factory BannerItem.fromJson(Map<String, dynamic> json) => BannerItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString(),
        characterId: json['characterId']?.toString(),
      );
}
