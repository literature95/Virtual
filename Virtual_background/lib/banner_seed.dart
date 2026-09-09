/// 首页轮播位（Banner）
///
/// 运营位数据量小、无用户数据，因此不进数据库表，直接以常量维护；
/// 相对路径的绝对 URL 由路由层按请求来源补全（`avatar_url.dart`）。
///
/// **必须配横版图**：轮播是横幅构图，正好复用角色立绘原图
/// （`char-00X.jpg`，1368×768 / 16:9）。同一批素材塞进 0.62 的竖版封面卡
/// 会被 cover 裁掉大半，放进横幅则是原生比例、物尽其用。
class BannerSeed {
  const BannerSeed._();

  static const List<Map<String, dynamic>> items = [
    {
      'id': 'banner-001',
      'title': '晓夜 · 深夜便利店',
      'subtitle': '「要不要热一下？」她从不安慰人，只让你知道这里有人醒着',
      'imageUrl': '/avatars/char-001.jpg',
      'characterId': 'char-001',
    },
    {
      'id': 'banner-002',
      'title': '星尘 · 降临观测者',
      'subtitle': '光球从三层楼的高度缓缓沉下来，在离地面一米处收束成人形',
      'imageUrl': '/avatars/char-002.jpg',
      'characterId': 'char-002',
    },
    {
      'id': 'banner-003',
      'title': '墨书 · 写字先生',
      'subtitle': '替人抄书、写状纸、代拟家信，欠着纸铺二两银子',
      'imageUrl': '/avatars/char-003.jpg',
      'characterId': 'char-003',
    },
    {
      'id': 'banner-004',
      'title': 'Aurora · 泛用型预测意志',
      'subtitle': '她的投影比上次淡了 3%，但仍然坐在了你的对面',
      'imageUrl': '/avatars/char-004.jpg',
      'characterId': 'char-004',
    },
    {
      'id': 'banner-005',
      'title': '喵子 · 猫爪咖啡馆',
      'subtitle': '推开绘着猫爪印的木门，铃铛「叮当」响了两声',
      'imageUrl': '/avatars/char-005.jpg',
      'characterId': 'char-005',
    },
  ];
}
