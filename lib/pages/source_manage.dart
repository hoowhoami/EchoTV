import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/config_service.dart';
import '../models/site.dart';
import '../widgets/zen_ui.dart';
import '../widgets/edit_dialog.dart';

class SourceManagePage extends ConsumerStatefulWidget {
  const SourceManagePage({Key? key}) : super(key: key);

  @override
  ConsumerState<SourceManagePage> createState() => _SourceManagePageState();
}

class _SourceManagePageState extends ConsumerState<SourceManagePage> {
  List<SiteConfig> _sites = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final sites = await ref.read(configServiceProvider).getSites();
    setState(() => _sites = sites);
  }

  void _showSiteDialog({SiteConfig? site, int? index}) {
    final nameController = TextEditingController(text: site?.name);
    final apiController = TextEditingController(text: site?.api);
    showDialog(
      context: context,
      builder: (context) => EditDialog(
        title: Text(site == null ? '添加视频源' : '编辑视频源', style: const TextStyle(fontWeight: FontWeight.bold)),
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
              controller: apiController, 
              decoration: InputDecoration(
                labelText: 'API 地址',
                filled: true,
                fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: Theme.of(context).colorScheme.secondary))),
          TextButton(
            onPressed: () async {
              if (apiController.text.isNotEmpty) {
                final newSite = SiteConfig(
                  key: site?.key ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.isEmpty ? '新站点' : nameController.text,
                  api: apiController.text,
                );
                if (index != null) {
                  _sites[index] = newSite;
                } else {
                  _sites.add(newSite);
                }
                await ref.read(configServiceProvider).saveSites(_sites);
                _load();
                Navigator.pop(context);
              }
            },
            child: Text(site == null ? '添加' : '保存', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
          SliverAppBar(
            backgroundColor: Colors.transparent,
            expandedHeight: isPC ? 120 : 110,
            floating: true,
            automaticallyImplyLeading: false, // 禁用原生返回按钮
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: EdgeInsets.only(left: horizontalPadding, right: horizontalPadding, bottom: 12),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(LucideIcons.chevronLeft, size: 16, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '视频源管理', 
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: isPC ? 15 : 13, fontWeight: FontWeight.w900)
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '管理和配置 CMS 资源接口', 
                    style: theme.textTheme.labelMedium?.copyWith(fontSize: 8, letterSpacing: 0.5, color: theme.colorScheme.secondary.withValues(alpha: 0.5))
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => _showSiteDialog(), 
                icon: const Icon(LucideIcons.plusCircle, size: 20)
              ),
              SizedBox(width: horizontalPadding - 16),
            ],
          ),
          
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final site = _sites[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ZenGlassContainer(
                      borderRadius: 20,
                      blur: 10,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        title: Text(site.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(site.api, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.secondary, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(LucideIcons.edit3, size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                              onPressed: () => _showSiteDialog(site: site, index: index),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: theme.colorScheme.surface,
                                    title: const Text('确认删除'),
                                    content: Text('确定要删除视频源 "${site.name}" 吗？'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Colors.redAccent))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  _sites.removeAt(index);
                                  await ref.read(configServiceProvider).saveSites(_sites);
                                  _load();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _sites.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
