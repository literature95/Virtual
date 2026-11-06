import 'local_model_service_base.dart';
import 'local_model_service_stub.dart'
    if (dart.library.io) 'local_model_service_io.dart' as impl;

export 'local_model_service_base.dart';

/// 全局单例：VM/移动端走真实文件实现，Web 走不支持提示实现。
final LocalModelService localModelService = impl.createLocalModelService();
