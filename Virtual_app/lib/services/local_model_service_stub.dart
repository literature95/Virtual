import 'local_model_service_base.dart';

/// Web 端：可以编译、可以进入部署型端点，但明确提示不支持本地推理/导入。
class LocalModelServiceStub implements LocalModelService {
  @override
  bool get supported => false;

  @override
  Future<String> modelsDirectory() async => '';

  @override
  Future<LocalModelStatus> inspect(String path) async => LocalModelStatus.missing;

  @override
  Future<LocalModelImportResult> importGguf({
    required String sourcePath,
    required int sourceBytes,
    String? preferredName,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    throw const LocalModelImportException('Web 端不支持本地模型导入，请在 Android/iOS 客户端操作');
  }

  @override
  Future<bool> deleteManaged(String path) async => false;

  @override
  Future<bool> isManagedPath(String path) async => false;
}

LocalModelService createLocalModelService() => LocalModelServiceStub();
