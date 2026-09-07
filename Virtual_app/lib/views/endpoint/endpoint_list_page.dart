import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/endpoint_provider.dart';
import '../../theme/tavo_brand.dart';

class EndpointListPage extends StatelessWidget {
  const EndpointListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('接口'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新接口',
            onPressed: () => context.go('/endpoint/new'),
          ),
        ],
      ),
      body: Consumer<EndpointProvider>(
        builder: (context, provider, _) {
          if (provider.llmEndpoints.isEmpty) {
            return const _EmptyEndpointState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: provider.llmEndpoints.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ep = provider.llmEndpoints[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(_getPlatformIcon(ep.platform)),
                  ),
                  title: Row(
                    children: [
                      Text(ep.name),
                      if (ep.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '默认',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text('${ep.platform} · ${ep.models.length} 个模型'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/endpoint/${ep.id}/edit'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: TavoBrand.extendedFab(
        onPressed: () => context.go('/endpoint/new'),
        icon: const Icon(Icons.add),
        label: const Text('新接口'),
      ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'openai':
        return Icons.smart_toy;
      case 'anthropic':
      case 'claude':
        return Icons.psychology;
      case 'gemini':
        return Icons.auto_awesome;
      case 'deepseek':
        return Icons.search;
      case 'openrouter':
        return Icons.route;
      default:
        return Icons.api;
    }
  }
}

class _EmptyEndpointState extends StatelessWidget {
  const _EmptyEndpointState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 官方空状态插画
            Image.asset(
              'assets/images/empty_state_endpoint.png',
              width: 140,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(Icons.public_outlined, size: 64, color: Colors.grey[350]),
            ),
            const SizedBox(height: 14),
            Text('暂无API连接', style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            // 说明卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'API 是我们与 AI 平台之间建立的连接，我们将通过它调用大模型来驱动AI角色扮演。它也是您在本地运行 AI 的必备条件。',
                    style: TextStyle(fontSize: 13.5, height: 1.6, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右上角添加第一个 API 连接吧！',
                    style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
