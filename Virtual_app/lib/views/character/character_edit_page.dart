import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../models/character.dart';
import '../../models/lorebook.dart';
import '../../models/persona.dart';
import '../../providers/character_provider.dart';

/// 角色编辑页
///
/// 包含 4 个 Tab：基本信息、角色设定、对话、高级
/// 支持新建和编辑两种模式
class CharacterEditPage extends StatefulWidget {
  final String? characterId;

  const CharacterEditPage({super.key, this.characterId});

  @override
  State<CharacterEditPage> createState() => _CharacterEditPageState();
}

class _CharacterEditPageState extends State<CharacterEditPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 基本信息
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _tagController = TextEditingController();
  List<String> _tags = [];
  String? _avatarPath;

  // 角色设定
  final _descriptionController = TextEditingController();
  final _personalityController = TextEditingController();
  final _scenarioController = TextEditingController();
  final _creatorNotesController = TextEditingController();
  bool _creatorNotesExpanded = false;

  // 对话
  final _firstMessageController = TextEditingController();
  final List<TextEditingController> _alternateGreetingControllers = [];
  List<CharacterExampleMessage> _exampleMessages = [];

  // 高级
  String? _selectedLorebookId;
  String? _selectedPersonaId;
  CharacterBubbleStyle _bubbleStyle = CharacterBubbleStyle.standard;
  CharacterAvatarStyle _avatarStyle = CharacterAvatarStyle.circle;

  bool _isEditing = false;
  bool _isLoading = true;

  // Lorebook & Persona 列表（预留接口，当前为空）
  List<Lorebook> _lorebooks = [];
  List<Persona> _personas = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _isEditing = widget.characterId != null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _descriptionController.dispose();
    _personalityController.dispose();
    _scenarioController.dispose();
    _firstMessageController.dispose();
    _creatorNotesController.dispose();
    _tagController.dispose();
    for (final ctrl in _alternateGreetingControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    // 加载 Lorebook 和 Persona 列表（预留接口，从数据库获取）
    final db = context.read<AppDatabase>();
    _lorebooks = db.getLorebooks();
    _personas = db.getPersonas();

    if (_isEditing) {
      final provider = context.read<CharacterProvider>();
      final character = provider.findById(widget.characterId!);
      if (character != null) {
        _populateFromCharacter(character);
      }
    } else {
      // 新建模式，添加一个空的替代问候方便用户编辑
      _addAlternateGreeting(empty: true);
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _populateFromCharacter(Character character) {
    _nameController.text = character.name;
    _nicknameController.text = character.nickname ?? '';
    _descriptionController.text = character.description ?? '';
    _personalityController.text = character.personality ?? '';
    _scenarioController.text = character.scenario ?? '';
    _firstMessageController.text = character.firstMessage ?? '';
    _creatorNotesController.text = character.creatorNotes ?? '';
    _tags = List.from(character.tags);
    _avatarPath = character.avatarPath;
    _bubbleStyle = character.bubbleStyle;
    _avatarStyle = character.avatarStyle;
    _selectedLorebookId = character.lorebookId;
    _selectedPersonaId = character.personaId;
    _exampleMessages = List.from(character.exampleMessages);

    // 填充替代问候
    _alternateGreetingControllers.clear();
    if (character.alternateGreetings.isNotEmpty) {
      for (final greeting in character.alternateGreetings) {
        _alternateGreetingControllers
            .add(TextEditingController(text: greeting));
      }
    } else {
      _alternateGreetingControllers.add(TextEditingController());
    }
  }

  Future<void> _saveCharacter() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入角色名称')),
      );
      _tabController.animateTo(0);
      return;
    }

    final provider = context.read<CharacterProvider>();

    // 收集替代问候（过滤空值）
    final alternateGreetings = _alternateGreetingControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (_isEditing) {
      final existing = provider.findById(widget.characterId!);
      if (existing != null) {
        final updated = existing.copyWith(
          name: name,
          nickname: _nicknameController.text.trim().isEmpty
              ? null
              : _nicknameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          personality: _personalityController.text.trim().isEmpty
              ? null
              : _personalityController.text.trim(),
          scenario: _scenarioController.text.trim().isEmpty
              ? null
              : _scenarioController.text.trim(),
          firstMessage: _firstMessageController.text.trim().isEmpty
              ? null
              : _firstMessageController.text.trim(),
          creatorNotes: _creatorNotesController.text.trim().isEmpty
              ? null
              : _creatorNotesController.text.trim(),
          avatarPath: _avatarPath,
          tags: _tags,
          alternateGreetings: alternateGreetings,
          exampleMessages: _exampleMessages,
          lorebookId: _selectedLorebookId,
          personaId: _selectedPersonaId,
          bubbleStyle: _bubbleStyle,
          avatarStyle: _avatarStyle,
        );
        await provider.updateCharacter(updated);
      }
    } else {
      await provider.createCharacter(
        name: name,
        nickname: _nicknameController.text.trim().isEmpty
            ? null
            : _nicknameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        personality: _personalityController.text.trim().isEmpty
            ? null
            : _personalityController.text.trim(),
        scenario: _scenarioController.text.trim().isEmpty
            ? null
            : _scenarioController.text.trim(),
        firstMessage: _firstMessageController.text.trim().isEmpty
            ? null
            : _firstMessageController.text.trim(),
        creatorNotes: _creatorNotesController.text.trim().isEmpty
            ? null
            : _creatorNotesController.text.trim(),
        avatarPath: _avatarPath,
        tags: _tags,
        alternateGreetings: alternateGreetings,
        exampleMessages: _exampleMessages,
        lorebookId: _selectedLorebookId,
        personaId: _selectedPersonaId,
        bubbleStyle: _bubbleStyle,
        avatarStyle: _avatarStyle,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功'), duration: Duration(seconds: 1)),
      );
      Navigator.of(context).pop();
    }
  }

  // ==================== 标签相关 ====================

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  // ==================== 替代问候相关 ====================

  void _addAlternateGreeting({bool empty = false}) {
    setState(() {
      _alternateGreetingControllers.add(
        TextEditingController(text: empty ? '' : ''),
      );
    });
  }

  void _removeAlternateGreeting(int index) {
    setState(() {
      _alternateGreetingControllers[index].dispose();
      _alternateGreetingControllers.removeAt(index);
    });
  }

  // ==================== 示例消息相关 ====================

  Future<void> _showExampleDialog(
      {CharacterExampleMessage? existing, int? index}) async {
    final userMsgController =
        TextEditingController(text: existing?.userMessage ?? '');
    final assistantMsgController =
        TextEditingController(text: existing?.assistantMessage ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');

    final result = await showDialog<CharacterExampleMessage>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? '添加示例对话' : '编辑示例对话'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userMsgController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '用户消息',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    hintText: '用户说的话',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: assistantMsgController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '角色回复',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    hintText: '角色应该如何回复',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    border: OutlineInputBorder(),
                    hintText: '这个示例的说明',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final userMsg = userMsgController.text.trim();
              final assistantMsg = assistantMsgController.text.trim();
              if (userMsg.isEmpty || assistantMsg.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写用户消息和角色回复')),
                );
                return;
              }
              Navigator.pop(
                context,
                CharacterExampleMessage(
                  userMessage: userMsg,
                  assistantMessage: assistantMsg,
                  note: noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        if (index != null) {
          _exampleMessages[index] = result;
        } else {
          _exampleMessages.add(result);
        }
      });
    }

    userMsgController.dispose();
    assistantMsgController.dispose();
    noteController.dispose();
  }

  void _removeExampleMessage(int index) {
    setState(() => _exampleMessages.removeAt(index));
  }

  void _moveExampleMessage(int index, bool up) {
    final newIndex = up ? index - 1 : index + 1;
    if (newIndex < 0 || newIndex >= _exampleMessages.length) return;
    setState(() {
      final item = _exampleMessages.removeAt(index);
      _exampleMessages.insert(newIndex, item);
    });
  }

  // ==================== 头像选择 ====================

  void _onAvatarTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('暂无图片，后续版本支持'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ==================== 删除角色 ====================

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除角色'),
        content: const Text('确定要删除这个角色吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.characterId != null) {
      final provider = context.read<CharacterProvider>();
      await provider.deleteCharacter(widget.characterId!);
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? '编辑角色' : '新角色'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑角色' : '新角色'),
        actions: [
          TextButton(
            onPressed: _saveCharacter,
            child: const Text('保存'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '基本信息'),
            Tab(text: '角色设定'),
            Tab(text: '对话'),
            Tab(text: '高级'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicTab(),
          _buildPersonalityTab(),
          _buildDialogueTab(),
          _buildAdvancedTab(),
        ],
      ),
    );
  }

  // ==================== Tab 1: 基本信息 ====================

  Widget _buildBasicTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 头像
        Center(
          child: GestureDetector(
            onTap: _onAvatarTap,
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: _avatarPath != null
                  ? ClipOval(
                      child: Image.asset(
                        _avatarPath!,
                        fit: BoxFit.cover,
                        width: 96,
                        height: 96,
                      ),
                    )
                  : Icon(
                      Icons.add_a_photo,
                      size: 32,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _onAvatarTap,
            icon: const Icon(Icons.upload, size: 16),
            label: const Text('上传头像'),
          ),
        ),
        const SizedBox(height: 16),
        // 角色名称
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '角色名称 *',
            border: OutlineInputBorder(),
            hintText: '角色的名字',
          ),
          validator: (value) =>
              value?.trim().isEmpty == true ? '请输入角色名称' : null,
        ),
        const SizedBox(height: 16),
        // 昵称
        TextFormField(
          controller: _nicknameController,
          decoration: const InputDecoration(
            labelText: '昵称',
            border: OutlineInputBorder(),
            hintText: '可选，角色的称呼或小名',
          ),
        ),
        const SizedBox(height: 24),
        // 标签
        const Text(
          '标签',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ..._tags.map((tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => _removeTag(tag),
                  deleteIconColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                )),
            SizedBox(
              width: 140,
              child: TextFormField(
                controller: _tagController,
                decoration: const InputDecoration(
                  hintText: '添加标签 + 回车',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                onFieldSubmitted: (_) => _addTag(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== Tab 2: 角色设定 ====================

  Widget _buildPersonalityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 角色描述
        TextFormField(
          controller: _descriptionController,
          maxLines: null,
          minLines: 3,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            labelText: '角色描述',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
            hintText:
                '一句话或一段话介绍这个角色\n\n支持宏变量：{{char}} {{user}} {{personality}} {{scenario}}',
          ),
        ),
        const SizedBox(height: 16),
        // 性格
        TextFormField(
          controller: _personalityController,
          maxLines: null,
          minLines: 6,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            labelText: '性格',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
            hintText: '描述角色的性格特点、说话方式、行为模式等',
          ),
        ),
        const SizedBox(height: 16),
        // 场景
        TextFormField(
          controller: _scenarioController,
          maxLines: null,
          minLines: 5,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            labelText: '场景',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
            hintText: '故事背景、世界观、角色所处的情境',
          ),
        ),
        const SizedBox(height: 24),
        // 创作者备注（折叠）
        ExpansionTile(
          title: const Text(
            '创作者备注',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: const Text('给自己看的创作思路、注意事项等'),
          initiallyExpanded: _creatorNotesExpanded,
          onExpansionChanged: (expanded) {
            setState(() => _creatorNotesExpanded = expanded);
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextFormField(
                controller: _creatorNotesController,
                maxLines: null,
                minLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '记录你的创作想法、设计思路、待改进项等',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== Tab 3: 对话 ====================

  Widget _buildDialogueTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 首条消息
        TextFormField(
          controller: _firstMessageController,
          maxLines: null,
          minLines: 4,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            labelText: '首条消息',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
            hintText: '新对话开始时，角色会主动发送的第一条消息',
            helperText: '角色会在对话开始时主动发送这条消息',
          ),
        ),
        const SizedBox(height: 24),
        // 替代问候
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '替代问候',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
            TextButton.icon(
              onPressed: () => _addAlternateGreeting(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '可选的备选问候语，开启新对话时会随机选择一条',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        ...List.generate(_alternateGreetingControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _alternateGreetingControllers[index],
                    maxLines: 2,
                    minLines: 1,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: '替代问候语 ${index + 1}',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () => _removeAlternateGreeting(index),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 24),
        // 示例消息
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '示例消息',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
            TextButton.icon(
              onPressed: () => _showExampleDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '通过示例对话来定义角色的说话风格和反应方式',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        if (_exampleMessages.isEmpty)
          Card(
            elevation: 0,
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 32, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('还没有示例消息', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          )
        else
          ...List.generate(_exampleMessages.length, (index) {
            final example = _exampleMessages[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 序号和操作
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '#${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                        if (example.note != null &&
                            example.note!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              example.note!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        // 上移
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          onPressed: index > 0
                              ? () => _moveExampleMessage(index, true)
                              : null,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                        // 下移
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 18),
                          onPressed: index < _exampleMessages.length - 1
                              ? () => _moveExampleMessage(index, false)
                              : null,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                        // 编辑
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showExampleDialog(
                            existing: example,
                            index: index,
                          ),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                        // 删除
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Theme.of(context).colorScheme.error,
                          onPressed: () => _removeExampleMessage(index),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 用户消息
                    _buildExampleMessageRow(
                      context,
                      label: '用户',
                      content: example.userMessage,
                      isUser: true,
                    ),
                    const SizedBox(height: 6),
                    // 角色消息
                    _buildExampleMessageRow(
                      context,
                      label: '角色',
                      content: example.assistantMessage,
                      isUser: false,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildExampleMessageRow(
    BuildContext context, {
    required String label,
    required String content,
    required bool isUser,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isUser
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.tertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            content,
            style: const TextStyle(fontSize: 13, height: 1.4),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==================== Tab 4: 高级 ====================

  Widget _buildAdvancedTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 关联 Lorebook
        const _SectionTitle('关联 Lorebook'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _selectedLorebookId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Lorebook / 知识书',
            hintText: '选择一个 Lorebook',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('无'),
            ),
            ..._lorebooks.map((l) => DropdownMenuItem<String?>(
                  value: l.id,
                  child: Text(l.name),
                )),
          ],
          onChanged: (value) {
            setState(() => _selectedLorebookId = value);
          },
          disabledHint: const Text('暂无 Lorebook'),
        ),
        if (_lorebooks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '暂无可用的 Lorebook',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        const SizedBox(height: 24),

        // 关联 Persona
        const _SectionTitle('关联 Persona'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _selectedPersonaId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Persona / 用户人设',
            hintText: '选择一个 Persona',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('无'),
            ),
            ..._personas.map((p) => DropdownMenuItem<String?>(
                  value: p.id,
                  child: Text(p.name),
                )),
          ],
          onChanged: (value) {
            setState(() => _selectedPersonaId = value);
          },
          disabledHint: const Text('暂无 Persona'),
        ),
        if (_personas.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '暂无可用的 Persona',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        const SizedBox(height: 24),

        // 气泡样式
        const _SectionTitle('气泡样式'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CharacterBubbleStyle.values.map((style) {
            final isSelected = _bubbleStyle == style;
            return ChoiceChip(
              label: Text(_bubbleStyleLabel(style)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _bubbleStyle = style);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // 头像样式
        const _SectionTitle('头像样式'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CharacterAvatarStyle.values.map((style) {
            final isSelected = _avatarStyle == style;
            return ChoiceChip(
              label: Text(_avatarStyleLabel(style)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _avatarStyle = style);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 32),

        // 删除角色（仅编辑模式）
        if (_isEditing) ...[
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              '删除角色',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('永久删除此角色及其所有数据'),
            onTap: _confirmDelete,
          ),
        ],
      ],
    );
  }

  String _bubbleStyleLabel(CharacterBubbleStyle style) {
    switch (style) {
      case CharacterBubbleStyle.standard:
        return '标准';
      case CharacterBubbleStyle.flat:
        return '扁平';
      case CharacterBubbleStyle.minimal:
        return '极简';
      case CharacterBubbleStyle.custom:
        return '自定义';
    }
  }

  String _avatarStyleLabel(CharacterAvatarStyle style) {
    switch (style) {
      case CharacterAvatarStyle.circle:
        return '圆形';
      case CharacterAvatarStyle.square:
        return '方形';
      case CharacterAvatarStyle.rounded:
        return '圆角';
      case CharacterAvatarStyle.none:
        return '无';
    }
  }
}

/// 分组标题组件
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
    );
  }
}
