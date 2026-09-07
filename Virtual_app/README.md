# Virtual

Virtual 是一个基于 Flutter 的 AI 角色聊天客户端，定位为“本地优先、角色扮演、跨模型接入”的应用。

它目前的代码结构已经具备完整的客户端闭环：角色管理、聊天历史、模型端点配置、主题设置、插件/世界书/预设/正则规则等模块均在项目中实现。

## 项目概览

Virtual 不是一个单纯的聊天 Demo，而是一个偏 AI 客户端的应用框架，核心能力包括：

- AI 角色聊天
- 多角色卡管理
- 会话与消息持久化
- 多 LLM 接入端点配置
- 角色设定、世界书、预设、正则规则等扩展能力
- TTS / ASR / Web Search / Image Generation 等功能入口
- 本地设置、备份和调试能力

## 技术栈

- Flutter
- Dart
- Provider（状态管理）
- GoRouter（路由）
- SharedPreferences + JSON（本地存储）
- Dio / Http（网络请求）
- multi-model adapters：OpenAI / Anthropic / Gemini
- Flutter UI 组件：Material, Lottie, Markdown, Image Picker, WebView 等

## 代码结构

```text
lib/
  main.dart                    # 应用入口
  data/
    app_database.dart          # 本地数据存储与 CRUD
  models/                      # 数据模型
  providers/                   # 状态管理
    settings_provider.dart
    metadata_provider.dart
    endpoint_provider.dart
    character_provider.dart
    chat_provider.dart
  route/
    app_router.dart            # 路由配置
  services/
    api_service.dart
    backend_config.dart
    model_registry_service.dart
    metadata_service.dart
    prompt_service.dart
    adapters/
      openai_adapter.dart
      anthropic_adapter.dart
      gemini_adapter.dart
  theme/
    app_theme.dart
    tavo_brand.dart
  utils/
    constants.dart
  views/
    onboarding/
    chat/
    character/
    endpoint/
    lorebook/
    regex/
    preset/
    settings/
    theme/
    plugin/
    more/
    debug/
```

## 关键业务模块

### 1. App 启动与全局状态

入口位于 [lib/main.dart](lib/main.dart)。

启动流程包括：

- 初始化 Flutter 绑定
- 初始化 Sentry
- 获取 SharedPreferences
- 初始化本地数据库
- 强制竖屏
- 注册全局 Provider
- 判断是否完成 onboarding
  - 未完成：显示引导页
  - 完成：进入主路由

### 2. 路由

路由定义在 [lib/route/app_router.dart](lib/route/app_router.dart)。

当前主路由包括：

- /chat
- /chat/:id
- /characters
- /character/new
- /character/:id/edit
- /endpoints
- /endpoint/new
- /endpoint/:id/edit
- /lorebooks
- /regex
- /presets
- /settings
- /plugins
- /more
- /debug

### 3. 本地数据库

[lib/data/app_database.dart](lib/data/app_database.dart) 是本项目的核心数据存储层，采用 SharedPreferences + JSON 保存数据，支持：

- characters
- conversations
- messages
- endpoints
- lorebooks
- presets
- regex rules
- themes
- personas
- plugins

这种设计的特点是：

- 启动简单，不依赖复杂本地数据库依赖
- 适合轻量桌面/移动端应用
- 易于扩展成更重的持久化方案

### 4. 聊天能力

[lib/providers/chat_provider.dart](lib/providers/chat_provider.dart) 是聊天逻辑核心，负责：

- 加载对话列表
- 创建/删除/置顶对话
- 加载消息
- 自动插入角色首条欢迎消息
- 发送消息
- 自动选择当前 endpoint 和 model
- 调用 API 生成回复
- 处理中断、流式输出、错误状态

### 5. 模型与端点管理

端点和模型配置位于：

- [lib/providers/endpoint_provider.dart](lib/providers/endpoint_provider.dart)
- [lib/services/model_registry_service.dart](lib/services/model_registry_service.dart)
- [lib/services/adapters](lib/services/adapters)

项目支持多家模型接入，当前实现中已具备 OpenAI / Anthropic / Gemini 适配器结构，说明应用设计目标是“多模型切换”，不是单一厂商绑定。

### 6. 角色与详细配置

角色、人物卡、世界书、预设和规则等均有对应视图和模型：

- [lib/models/character.dart](lib/models/character.dart)
- [lib/models/lorebook.dart](lib/models/lorebook.dart)
- [lib/models/preset.dart](lib/models/preset.dart)
- [lib/models/regex_rule.dart](lib/models/regex_rule.dart)
- [lib/views/character](lib/views/character)
- [lib/views/lorebook](lib/views/lorebook)
- [lib/views/preset](lib/views/preset)
- [lib/views/regex](lib/views/regex)

这些模块构成“角色扮演应用”的核心配置层。

## 运行方式

安装依赖：

```bash
flutter pub get
```

启动应用：

```bash
flutter run
```

如果需要运行测试：

```bash
flutter test
```

## 构建说明

项目在 [pubspec.yaml](pubspec.yaml) 中定义了应用名为 `virtual`，并声明了 Flutter 3.19+ / Dart SDK 3.3+ 的最低要求。

Android / Web 入口也已同步更新为 Virtual 相关名称，但底层包名、签名名和远程服务地址仍可能保留旧的 `tav` / `tavo` 标识，这些通常属于发布和包管理层面的兼容性配置。

## 设计特点

1. 轻量本地优先
   - 本地 JSON 持久化，便于快速启动和调试。

2. 模块可扩展
   - API、角色、世界书、插件、设置都按独立模块拆分。

3. 面向 AI 角色扮演
   - 从会话、角色设定、模型端点到扩展规则，均围绕 AI 角色体验设计。

4. 适合继续演进
   - 当前结构已经具备中型客户端的基础骨架，后续可继续扩展云同步、更稳定数据库、测试覆盖和发布流程。

## 注意事项

- 当前本地数据存储采用 SharedPreferences + JSON，适合中小规模场景，不适合超大规模数据查询。
- 项目包含较多功能入口，适合功能型 AI 客户端方案，但维护时需要注意模块边界和测试覆盖。
- 如果需要生产级交付，建议后续再补充：
  - 更稳定持久化层（如 SQLite / Drift / ObjectBox）
  - API 接口统一封装与错误重试
  - 单元测试和 widget 测试
  - CI/CD 与版本发布流程

## 结论

Virtual 是一个具有较完整业务闭环的 Flutter AI 角色聊天应用，代码结构已经相对成熟，适合继续迭代成正式产品。当前 README 与代码的实际状态基本一致，重点是“AI 角色通信 + 多模型接入 + 本地数据管理”的组合能力。
