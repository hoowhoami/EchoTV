import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/config_service.dart';
import '../services/subscription_service.dart';
import '../models/subscription.dart';
import '../widgets/zen_ui.dart';
import '../widgets/edit_dialog.dart';

class SubscriptionManagePage extends ConsumerStatefulWidget {
  const SubscriptionManagePage({Key? key}) : super(key: key);

  @override
  ConsumerState<SubscriptionManagePage> createState() => _SubscriptionManagePageState();
}

class _SubscriptionManagePageState extends ConsumerState<SubscriptionManagePage> {
  List<Subscription> _subscriptions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final subs = await ref.read(configServiceProvider).getSubscriptions();
    setState(() => _subscriptions = subs);
  }

  void _showSubscriptionDialog({Subscription? sub, int? index}) {
    final nameController = TextEditingController(text: sub?.name);
    final urlController = TextEditingController(text: sub?.url);
    bool autoUpdate = sub?.autoUpdate ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => EditDialog(
          title: Text(sub == null ? '添加订阅' : '编辑订阅', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '名称',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: '订阅链接 (JSON URL)',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              _buildSwitchTile(
                title: '自动更新',
                subtitle: '开启后每天自动同步配置',
                value: autoUpdate,
                onChanged: (val) => setDialogState(() => autoUpdate = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: Theme.of(context).colorScheme.secondary))),
            TextButton(
              onPressed: () async {
                if (urlController.text.isNotEmpty) {
                  final newSub = Subscription(
                    id: sub?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.isEmpty ? '新订阅' : nameController.text,
                    url: urlController.text,
                    autoUpdate: autoUpdate,
                    enabled: sub?.enabled ?? true,
                    lastUpdate: sub?.lastUpdate,
                  );
                  
                  if (index != null) {
                    _subscriptions[index] = newSub;
                  } else {
                    _subscriptions.add(newSub);
                  }
                  
                  await ref.read(configServiceProvider).saveSubscriptions(_subscriptions);
                  _load();
                  Navigator.pop(context);

                  // 如果是新添加或链接变了，尝试刷新一次
                  if (sub == null || sub.url != newSub.url) {
                    _refreshSingle(newSub);
                  }
                }
              },
              child: Text(sub == null ? '添加' : '保存', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({required String title, required String subtitle, required bool value, required Function(bool) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  Future<void> _refreshSingle(Subscription sub) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(subscriptionServiceProvider).refreshSubscription(sub);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('订阅 "${sub.name}" 已刷新'), behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刷新失败: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSubscriptionContent(Subscription sub) async {
    final configService = ref.read(configServiceProvider);
    final allSites = await configService.getSitesAll();
    final allLives = await configService.getLiveSourcesAll();
    final allCats = await configService.getCategoriesAll();

    final subSites = allSites.where((s) => s.subscriptionId == sub.id).toList();
    final subLives = allLives.where((l) => l.subscriptionId == sub.id).toList();
    final subCats = allCats.where((c) => c.subscriptionId == sub.id).toList();

    final Map<String, dynamic> contentMap = {
      'api_site': {for (var s in subSites) s.key: s.toJson()},
      'lives': {for (var l in subLives) l.key: l.toJson()},
      'custom_category': subCats.map((c) => c.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(contentMap);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => EditDialog(
        title: Text('订阅内容: ${sub.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
        width: 600,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildStatItem('视频源', subSites.length),
                  const SizedBox(width: 24),
                  _buildStatItem('直播源', subLives.length),
                  const SizedBox(width: 24),
                  _buildStatItem('分类映射', subCats.length),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('原始 JSON 数据:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 300,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonString,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ZenButton(
            isSecondary: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          ZenButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonString));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('内容已复制到剪贴板'), behavior: SnackBarBehavior.floating));
              }
            },
            child: const Text('复制 JSON'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.secondary)),
        Text(count.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPC = MediaQuery.of(context).size.width > 800;
    final horizontalPadding = isPC ? 48.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          ZenSliverAppBar(
            title: '配置订阅管理',
            subtitle: '多订阅源管理与自动同步',
            actions: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              IconButton(onPressed: () => _showSubscriptionDialog(), icon: const Icon(LucideIcons.plusCircle, size: 20)),
            ],
          ),
          
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final sub = _subscriptions[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ZenGlassContainer(
                      borderRadius: 20,
                      blur: 10,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: sub.enabled ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            sub.enabled ? LucideIcons.rss : LucideIcons.rss,
                            color: sub.enabled ? theme.colorScheme.primary : theme.colorScheme.secondary,
                            size: 20,
                          ),
                        ),
                        title: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sub.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary)),
                            const SizedBox(height: 4),
                            Text(
                              sub.lastUpdate != null ? '上次更新: ${_formatDate(sub.lastUpdate!)}' : '未更新',
                              style: TextStyle(fontSize: 10, color: theme.colorScheme.secondary.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: sub.enabled,
                              onChanged: (val) async {
                                _subscriptions[index] = sub.copyWith(enabled: val);
                                await ref.read(configServiceProvider).saveSubscriptions(_subscriptions);
                                _load();
                              },
                              activeColor: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(LucideIcons.refreshCw, size: 18),
                              onPressed: () => _refreshSingle(sub),
                            ),
                            PopupMenuButton(
                              icon: const Icon(LucideIcons.moreVertical, size: 18),
                              borderRadius: BorderRadius.circular(16),
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'view', child: Row(children: [Icon(LucideIcons.eye, size: 16), SizedBox(width: 8), Text('查看内容')])),
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(LucideIcons.edit3, size: 16), SizedBox(width: 8), Text('编辑')])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent), SizedBox(width: 8), Text('删除', style: TextStyle(color: Colors.redAccent))])),
                              ],
                              onSelected: (val) async {
                                if (val == 'view') {
                                  _showSubscriptionContent(sub);
                                } else if (val == 'edit') {
                                  _showSubscriptionDialog(sub: sub, index: index);
                                } else if (val == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('确认删除'),
                                      content: Text('确定要删除订阅 "${sub.name}" 吗？相关的站点和分类映射也将被移除。'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Colors.redAccent))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await ref.read(configServiceProvider).removeSubscriptionData(sub.id);
                                    _subscriptions.removeAt(index);
                                    await ref.read(configServiceProvider).saveSubscriptions(_subscriptions);
                                    _load();
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _subscriptions.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
