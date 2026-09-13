import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/character.dart';
import '../models/lorebook.dart';
import '../utils/image_data.dart' show parseDataUrl;
import 'character_export_service.dart';

/// 一次发布的结果
class CharacterPublishResult {
  /// 后端卡 ID（slug 化后的身份）
  final String id;

  /// 实际写入的版本号
  final String characterVersion;

  /// 立绘地址（后端落盘路径或卡内透传外链）
  final String? avatarUrl;

  /// `created`（新卡）/ `updated`（同 id+version 覆盖）
  final String action;

  const CharacterPublishResult({
    required this.id,
    required this.characterVersion,
    required this.action,
    this.avatarUrl,
  });

  bool get created => action == 'created';
}

/// 角色卡发布（本地 → 后端数据库）
///
/// 对接 `POST /api/characters`（见 docs/character-publish-design.md §2）：
/// - `card`（form field）：[CharacterExportService.toCCv3] 产出的完整 spec 包，
///   世界书作为 `character_book` 随卡上送；
/// - `avatar`（form file，可选）：立绘字节，后端落 `public/uploads/`；
///   取不到字节（本地路径 / 资产路径）时不传，由后端按卡内 `avatar`
///   外链透传或存空 —— 上传失败不阻断发布。
///
/// **上传是显式动作**：导入 / 新建一律只进本地角色库，只有在这里才会
/// 写入后端数据库。
class CharacterPublishService {
  final Dio _dio;

  CharacterPublishService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  /// 发布单张本地角色卡到 [backend]（如 `http://localhost:8080`）
  Future<CharacterPublishResult> publish(
    Character character, {
    required String backend,
    Lorebook? lorebook,
  }) async {
    final card = CharacterExportService().toCCv3(character, lorebook: lorebook);

    final form = FormData();
    form.fields.add(MapEntry('card', jsonEncode(card)));

    final avatarBytes = await _resolveAvatarBytes(character.avatarPath);
    if (avatarBytes != null) {
      form.files.add(
        MapEntry(
          'avatar',
          MultipartFile.fromBytes(
            avatarBytes,
            filename: 'avatar.png',
            contentType: DioMediaType('image', 'png'),
          ),
        ),
      );
    }

    final base = backend.endsWith('/')
        ? backend.substring(0, backend.length - 1)
        : backend;
    final res = await _dio.post<Object>(
      '$base/api/characters',
      data: form,
    );

    final data = res.data;
    if (data is! Map) {
      throw Exception('后端响应格式异常：${res.statusCode}');
    }
    return CharacterPublishResult(
      id: data['id']?.toString() ?? '',
      characterVersion: data['characterVersion']?.toString() ?? '',
      avatarUrl: data['avatarUrl']?.toString(),
      action: data['action']?.toString() ?? 'created',
    );
  }

  /// 立绘 → 字节：`data:` URL 就地解码；http(s) 外链经 [Dio] 拉取。
  ///
  /// 返回 null = 交给后端按卡内 `avatar` 字段回退（本地路径 / 资产路径
  /// 在 Web 上无法读取，属正常情况而非错误）。
  Future<Uint8List?> _resolveAvatarBytes(String? path) async {
    if (path == null || path.isEmpty) return null;

    if (path.startsWith('data:')) {
      final parsed = parseDataUrl(path);
      if (parsed == null) return null;
      try {
        final data = parsed.$2;
        final padded = data.padRight((data.length + 3) & ~3, '=');
        return base64Decode(padded.replaceAll('-', '+').replaceAll('_', '/'));
      } catch (_) {
        return null;
      }
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      try {
        final res = await _dio.get<List<int>>(
          path,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = res.data;
        if (bytes == null || bytes.isEmpty) return null;
        return Uint8List.fromList(bytes);
      } catch (_) {
        return null;
      }
    }

    return null;
  }
}
