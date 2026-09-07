import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../models/regex_rule.dart';
import '../../services/regex_service.dart';

class RegexEditPage extends StatefulWidget {
  final String? regexId;

  const RegexEditPage({super.key, this.regexId});

  @override
  State<RegexEditPage> createState() => _RegexEditPageState();
}

class _RegexEditPageState extends State<RegexEditPage> {
  RegexRule? _rule;
  bool _isLoading = true;
  bool _isNew = false;

  late TextEditingController _nameController;
  late TextEditingController _patternController;
  late TextEditingController _replacementController;
  late TextEditingController _descriptionController;
  late TextEditingController _testInputController;

  RegexEntryTiming _timing = RegexEntryTiming.receive;
  RegexEntryPlacement _placement = RegexEntryPlacement.all;
  RegexEntrySubstitution _substitution = RegexEntrySubstitution.replaceAll;
  bool _enabled = true;
  bool _caseSensitive = false;
  bool _multiline = false;
  bool _dotAll = false;
  int _order = 0;

  String? _patternError;
  String _testResult = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _patternController = TextEditingController();
    _replacementController = TextEditingController();
    _descriptionController = TextEditingController();
    _testInputController = TextEditingController();

    _patternController.addListener(_validatePattern);

    if (widget.regexId == null) {
      _isNew = true;
      _isLoading = false;
    } else {
      _loadRule();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patternController.dispose();
    _replacementController.dispose();
    _descriptionController.dispose();
    _testInputController.dispose();
    super.dispose();
  }

  void _loadRule() {
    final db = context.read<AppDatabase>();
    final rules = db.getRegexRules();
    try {
      _rule = rules.firstWhere((r) => r.id == widget.regexId);
      _nameController.text = _rule!.name;
      _patternController.text = _rule!.pattern;
      _replacementController.text = _rule!.replacement;
      _descriptionController.text = _rule!.description ?? '';
      _timing = _rule!.timing;
      _placement = _rule!.placement;
      _substitution = _rule!.substitution;
      _enabled = _rule!.enabled;
      _caseSensitive = _rule!.caseSensitive;
      _multiline = _rule!.multiline;
      _dotAll = _rule!.dotAll;
      _order = _rule!.order;
    } catch (_) {
      _rule = null;
    }
    setState(() => _isLoading = false);
  }

  void _validatePattern() {
    final error = RegexService.validatePattern(
      _patternController.text,
      caseSensitive: _caseSensitive,
      multiline: _multiline,
      dotAll: _dotAll,
    );
    setState(() => _patternError = error);
  }

  void _runTest() {
    final rule = _buildRule();
    final input = _testInputController.text;
    setState(() {
      _testResult = rule.apply(input);
    });
  }

  RegexRule _buildRule() {
    return RegexRule(
      id: _rule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      pattern: _patternController.text,
      replacement: _replacementController.text,
      timing: _timing,
      placement: _placement,
      substitution: _substitution,
      enabled: _enabled,
      order: _order,
      caseSensitive: _caseSensitive,
      multiline: _multiline,
      dotAll: _dotAll,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );
  }

  Future<void> _save() async {
    if (_patternController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正则表达式')),
      );
      return;
    }
    if (_patternError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正则表达式有误: $_patternError')),
      );
      return;
    }

    final db = context.read<AppDatabase>();
    final rule = _buildRule();
    await db.saveRegexRule(rule);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已保存'),
          duration: Duration(seconds: 1),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('加载中...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新建正则规则' : '编辑正则规则'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '名称',
              border: OutlineInputBorder(),
              hintText: '规则名称（可选）',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _patternController,
            decoration: InputDecoration(
              labelText: '正则表达式 *',
              border: const OutlineInputBorder(),
              hintText: r'例如: \d+',
              errorText: _patternError,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _replacementController,
            decoration: const InputDecoration(
              labelText: '替换内容',
              border: OutlineInputBorder(),
              hintText: r'支持 $1, $2 捕获组引用',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RegexEntryTiming>(
            initialValue: _timing,
            decoration: const InputDecoration(
              labelText: '应用时机',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                  value: RegexEntryTiming.send, child: Text('发送时')),
              DropdownMenuItem(
                  value: RegexEntryTiming.receive, child: Text('接收时')),
              DropdownMenuItem(
                  value: RegexEntryTiming.display, child: Text('显示时')),
              DropdownMenuItem(
                  value: RegexEntryTiming.sendDisplay, child: Text('发送时显示')),
              DropdownMenuItem(
                  value: RegexEntryTiming.receiveDisplay, child: Text('接收时显示')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _timing = v);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RegexEntrySubstitution>(
            initialValue: _substitution,
            decoration: const InputDecoration(
              labelText: '替换策略',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                  value: RegexEntrySubstitution.replaceAll,
                  child: Text('全部替换')),
              DropdownMenuItem(
                  value: RegexEntrySubstitution.replaceFirst,
                  child: Text('首次替换')),
              DropdownMenuItem(
                  value: RegexEntrySubstitution.append, child: Text('追加')),
              DropdownMenuItem(
                  value: RegexEntrySubstitution.prepend, child: Text('前置')),
              DropdownMenuItem(
                  value: RegexEntrySubstitution.remove, child: Text('移除')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _substitution = v);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RegexEntryPlacement>(
            initialValue: _placement,
            decoration: const InputDecoration(
              labelText: '替换位置',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                  value: RegexEntryPlacement.all, child: Text('全部')),
              DropdownMenuItem(
                  value: RegexEntryPlacement.first, child: Text('首次匹配')),
              DropdownMenuItem(
                  value: RegexEntryPlacement.last, child: Text('末次匹配')),
              DropdownMenuItem(
                  value: RegexEntryPlacement.exact, child: Text('精确位置')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _placement = v);
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('启用'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('大小写敏感'),
            value: _caseSensitive,
            onChanged: (v) {
              setState(() => _caseSensitive = v);
              _validatePattern();
            },
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('多行模式'),
            value: _multiline,
            onChanged: (v) {
              setState(() => _multiline = v);
              _validatePattern();
            },
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('点号匹配全部'),
            value: _dotAll,
            onChanged: (v) {
              setState(() => _dotAll = v);
              _validatePattern();
            },
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: '描述（可选）',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            '测试',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _testInputController,
            decoration: const InputDecoration(
              labelText: '测试文本',
              border: OutlineInputBorder(),
              hintText: '输入要测试的文本',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _runTest,
              child: const Text('运行测试'),
            ),
          ),
          if (_testResult.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '结果:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    _testResult,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
