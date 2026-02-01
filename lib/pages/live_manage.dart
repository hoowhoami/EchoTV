import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/config_service.dart';
import '../models/live.dart';
import '../widgets/zen_ui.dart';
import '../widgets/edit_dialog.dart';

class LiveManagePage extends ConsumerStatefulWidget {
  const LiveManagePage({super.key});

  @override
  ConsumerState<LiveManagePage> createState() => _LiveManagePageState();
}

class _LiveManagePageState extends ConsumerState<LiveManagePage> {
  List<LiveSource> _sources = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final sources = await ref.read(configServiceProvider).getLiveSources();
    setState(() => _sources = sources);
  }

  void _showSourceDialog({LiveSource? source, int? index}) {
    final nameController = TextEditingController(text: source?.name);
    final urlController = TextEditingController(text: source?.url);
    showDialog(
      context: context,
      builder: (context) => EditDialog(
        title: Text(source == null ? '添加直播源' : '编辑直播源', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: '源名称',
                filled: true,
                fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                labelText: 'M3U 链接',
                filled: true,
                fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          ZenButton(
            isSecondary: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ZenButton(
            onPressed: () async {
              if (urlController.text.isNotEmpty) {
                final newSource = LiveSource(
                  key: source?.key ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.isEmpty ? '新直播源' : nameController.text,
                  url: urlController.text,
                );
                if (index != null) {
                  _sources[index] = newSource;
                } else {
                  _sources.add(newSource);
                }
                await ref.read(configServiceProvider).saveLiveSources(_sources);
                _load();
                Navigator.pop(context);
              }
            },
            child: Text(source == null ? '添加' : '保存'),
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

    return ZenScaffold(
      body: CustomScrollView(
        slivers: [
          ZenSliverAppBar(
            title: '直播源管理',
            subtitle: '管理 M3U 订阅链接',
            actions: [
              IconButton(onPressed: () => _showSourceDialog(), icon: const Icon(LucideIcons.plusCircle, size: 20)),
            ],
          ),
          
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final source = _sources[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ZenGlassContainer(
                      borderRadius: 20,
                      blur: 10,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Icon(LucideIcons.tv, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                        title: Text(source.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(source.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.secondary, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(LucideIcons.edit3, size: 18), onPressed: () => _showSourceDialog(source: source, index: index)),
                            IconButton(
                              icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => EditDialog(
                                    title: const Text('确认删除'),
                                    content: Text('确定要删除直播源 "${source.name}" 吗？'),
                                    actions: [
                                      ZenButton(
                                        isSecondary: true,
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('取消'),
                                      ),
                                      ZenButton(
                                        backgroundColor: Colors.redAccent,
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('删除'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  _sources.removeAt(index);
                                  await ref.read(configServiceProvider).saveLiveSources(_sources);
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
                childCount: _sources.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
