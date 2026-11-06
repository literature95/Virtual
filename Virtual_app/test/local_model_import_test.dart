import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:virtual/services/gguf_header.dart';
import 'package:virtual/services/local_model_service_base.dart';
import 'package:virtual/services/local_model_service_io.dart';

Uint8List _ggufBytes({
  int version = 3,
  int bodyBytes = 512,
  List<int>? magic,
}) {
  final builder = BytesBuilder();
  builder.add(magic ?? const [0x47, 0x47, 0x55, 0x46]); // "GGUF"
  builder.add([
    version & 0xFF,
    (version >> 8) & 0xFF,
    (version >> 16) & 0xFF,
    (version >> 24) & 0xFF,
  ]);
  builder.add(Uint8List(bodyBytes));
  return builder.toBytes();
}

void main() {
  group('GGUF 头校验', () {
    test('合法 GGUF（v3）通过', () {
      final result = checkGgufHeader(_ggufBytes(version: 3));
      expect(result.valid, isTrue);
      expect(result.version, 3);
    });

    test('非 GGUF（改名的其它文件）被拒绝', () {
      // PNG 头改后缀
      final result = checkGgufHeader([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(result.valid, isFalse);
      expect(result.error, contains('不是 GGUF'));
    });

    test('空文件 / 不足 8 字节被拒绝', () {
      expect(checkGgufHeader(const []).valid, isFalse);
      expect(checkGgufHeader(const [0x47, 0x47, 0x55, 0x46]).valid, isFalse);
    });

    test('版本号不合理被拒绝', () {
      expect(checkGgufHeader(_ggufBytes(version: 0)).valid, isFalse);
      expect(checkGgufHeader(_ggufBytes(version: 9)).valid, isFalse);
    });
  });

  group('模型导入', () {
    late Directory modelsDir;
    late Directory externalDir;
    late LocalModelServiceIo service;

    setUp(() async {
      modelsDir = await Directory.systemTemp.createTemp('virtual-models-');
      externalDir = await Directory.systemTemp.createTemp('virtual-ext-');
      service = LocalModelServiceIo(modelsDirectoryOverride: modelsDir.path);
    });

    tearDown(() async {
      if (await modelsDir.exists()) await modelsDir.delete(recursive: true);
      if (await externalDir.exists()) {
        await externalDir.delete(recursive: true);
      }
    });

    test('导入：流式复制到模型目录并回填绝对路径', () async {
      final source = File('${externalDir.path}/tiny-model.gguf');
      final bytes = _ggufBytes();
      await source.writeAsBytes(bytes);

      final progress = <double>[];
      final result = await service.importGguf(
        sourcePath: source.path,
        sourceBytes: bytes.length,
        onProgress: progress.add,
      );

      expect(result.outcome, LocalModelImportOutcome.imported);
      expect(result.bytes, bytes.length);
      expect(result.path, joinModelPath(modelsDir.path, 'tiny-model.gguf'));
      expect(File(result.path).existsSync(), isTrue);
      expect(File('${result.path}.partial').existsSync(), isFalse);
      expect(progress.last, 1.0);
    });

    test('幂等：同名同大小文件直接跳过复制', () async {
      final source = File('${externalDir.path}/same.gguf');
      final bytes = _ggufBytes(bodyBytes: 256);
      await source.writeAsBytes(bytes);

      final first = await service.importGguf(
        sourcePath: source.path,
        sourceBytes: bytes.length,
      );
      expect(first.outcome, LocalModelImportOutcome.imported);

      final target = File(first.path);
      final modifiedBefore = target.lastModifiedSync();

      final second = await service.importGguf(
        sourcePath: source.path,
        sourceBytes: bytes.length,
      );
      expect(second.outcome, LocalModelImportOutcome.skipped);
      expect(second.path, first.path);
      expect(target.lastModifiedSync(), modifiedBefore);
      expect(target.lengthSync(), bytes.length);
    });

    test('取消导入：不留下目标文件与 .partial', () async {
      final source = File('${externalDir.path}/cancel.gguf');
      final bytes = _ggufBytes();
      await source.writeAsBytes(bytes);

      final result = await service.importGguf(
        sourcePath: source.path,
        sourceBytes: bytes.length,
        isCancelled: () => true,
      );

      expect(result.outcome, LocalModelImportOutcome.cancelled);
      final targetPath = joinModelPath(modelsDir.path, 'cancel.gguf');
      expect(File(targetPath).existsSync(), isFalse);
      expect(File('$targetPath.partial').existsSync(), isFalse);
    });

    test('文件头非法时拒绝导入，不创建任何文件', () async {
      final source = File('${externalDir.path}/fake.gguf');
      await source.writeAsBytes(Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0]));

      await expectLater(
        service.importGguf(
          sourcePath: source.path,
          sourceBytes: 8,
        ),
        throwsA(isA<LocalModelImportException>()),
      );
      expect(modelsDir.listSync(), isEmpty);
    });

    test('状态查询与删除：只删 App 目录内文件，外部路径不代删', () async {
      final managed = File(joinModelPath(modelsDir.path, 'managed.gguf'));
      await managed.writeAsBytes(_ggufBytes(bodyBytes: 128));
      final external = File('${externalDir.path}/external.gguf');
      await external.writeAsBytes(_ggufBytes(bodyBytes: 64));

      final status = await service.inspect(managed.path);
      expect(status.exists, isTrue);
      expect(status.bytes, managed.lengthSync());

      expect(await service.isManagedPath(managed.path), isTrue);
      expect(await service.deleteManaged(managed.path), isTrue);
      expect(managed.existsSync(), isFalse);

      expect(await service.isManagedPath(external.path), isFalse);
      expect(await service.deleteManaged(external.path), isFalse);
      expect(external.existsSync(), isTrue);
    });

    test('文件名与路径拼接兼容 Windows/Unix 分隔符', () {
      expect(modelFileNameFrom(r'C:\Users\me\Downloads\model.gguf'), 'model.gguf');
      expect(modelFileNameFrom('/storage/emulated/0/Download/model.gguf'), 'model.gguf');
      expect(joinModelPath('/data/models', 'a.gguf'), '/data/models/a.gguf');
      expect(joinModelPath(r'C:\data\models', 'a.gguf'), r'C:\data\models\a.gguf');
    });
  });
}
