import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart';
import '../../models/regex_rule.dart';

class RegexListPage extends StatefulWidget {
  const RegexListPage({super.key});

  @override
  State<RegexListPage> createState() => _RegexListPageState();
}

class _RegexListPageState extends State<RegexListPage> {
  List<RegexRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  void _loadRules() {
    final db = context.read<AppDatabase>();
    setState(() {
      _rules = db.getRegexRules();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('正则规则'),
      ),
      body: _rules.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _rules.length,
              itemBuilder: (context, index) {
                final rule = _rules[index];
                return _RegexRuleTile(
                  rule: rule,
                  onTap: () => context
                      .push('/regex/${rule.id}/edit')
                      .then((_) => _loadRules()),
                  onDelete: () => _confirmDelete(rule),
                  onToggle: () => _toggleRule(rule),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/regex/new').then((_) => _loadRules()),
        icon: const Icon(Icons.add),
        label: const Text('新建规则'),
      ),
    );
  }

  Future<void> _toggleRule(RegexRule rule) async {
    final db = context.read<AppDatabase>();
    final updated = rule.copyWith(enabled: !rule.enabled);
    await db.saveRegexRule(updated);
    _loadRules();
  }

  void _confirmDelete(RegexRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除正则规则'),
        content: Text('确定要删除「${rule.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final db = context.read<AppDatabase>();
              await db.deleteRegexRule(rule.id);
              _loadRules();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _RegexRuleTile extends StatelessWidget {
  final RegexRule rule;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _RegexRuleTile({
    required this.rule,
    required this.onTap,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final timingLabels = {
      RegexEntryTiming.send: '发送',
      RegexEntryTiming.receive: '接收',
      RegexEntryTiming.display: '显示',
      RegexEntryTiming.sendDisplay: '发送显示',
      RegexEntryTiming.receiveDisplay: '接收显示',
    };
    final substitutionLabels = {
      RegexEntrySubstitution.replaceAll: '全部替换',
      RegexEntrySubstitution.replaceFirst: '首次替换',
      RegexEntrySubstitution.append: '追加',
      RegexEntrySubstitution.prepend: '前置',
      RegexEntrySubstitution.remove: '移除',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rule.enabled
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.code,
            color: rule.enabled
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                rule.name.isEmpty ? rule.pattern : rule.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!rule.enabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('已禁用', style: TextStyle(fontSize: 10)),
              ),
          ],
        ),
        subtitle: Text(
          '${rule.pattern} -> ${rule.replacement.isEmpty ? '(空)' : rule.replacement}'
          ' | ${timingLabels[rule.timing] ?? ''} | ${substitutionLabels[rule.substitution] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: rule.enabled ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: rule.enabled,
              onChanged: (_) => onToggle(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
              tooltip: '删除',
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.code_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '还没有正则规则',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '创建正则规则来处理消息文本',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
