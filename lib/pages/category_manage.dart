import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/config_service.dart';
import '../models/site.dart';
import '../widgets/zen_ui.dart';
import '../widgets/edit_dialog.dart';

class CategoryManagePage extends ConsumerStatefulWidget {
  const CategoryManagePage({Key? key}) : super(key: key);

  @override
  ConsumerState<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends ConsumerState<CategoryManagePage> {
  List<CustomCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final cats = await ref.read(configServiceProvider).getCategories();
    setState(() => _categories = cats);
  }

  void _showCategoryDialog({CustomCategory? cat, int? index}) {
    final nameController = TextEditingController(text: cat?.name);
    final queryController = TextEditingController(text: cat?.query);
    String selectedType = cat?.type ?? 'movie';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => EditDialog(
          title: Text(cat == null ? '添加分类映射' : '编辑分类映射', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '显示名称',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'movie', child: Text('电影')),
                      DropdownMenuItem(value: 'tv', child: Text('剧集')),
                    ],
                    onChanged: (val) => setDialogState(() => selectedType = val!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: queryController,
                decoration: InputDecoration(
                  labelText: '查询关键词 (API 参数)',
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
                if (queryController.text.isNotEmpty) {
                  final newCat = CustomCategory(
                    name: nameController.text.isEmpty ? '新分类' : nameController.text,
                    type: selectedType,
                    query: queryController.text,
                  );
                  if (index != null) {
                    _categories[index] = newCat;
                  } else {
                    _categories.add(newCat);
                  }
                  await ref.read(configServiceProvider).saveCategories(_categories);
                  _load();
                  Navigator.pop(context);
                }
              },
              child: Text(cat == null ? '添加' : '保存', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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
          ZenSliverAppBar(
            title: '分类映射管理',
            subtitle: '自定义影视分类映射规则',
            actions: [
              IconButton(onPressed: () => _showCategoryDialog(), icon: const Icon(LucideIcons.plusCircle, size: 20)),
            ],
          ),
          
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final cat = _categories[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ZenGlassContainer(
                      borderRadius: 20,
                      blur: 10,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Icon(cat.type == 'movie' ? LucideIcons.film : LucideIcons.clapperboard, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                        title: Text(cat.name ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Query: ${cat.query}', style: TextStyle(color: theme.colorScheme.secondary, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(LucideIcons.edit3, size: 18), onPressed: () => _showCategoryDialog(cat: cat, index: index)),
                            IconButton(
                              icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                              onPressed: () async {
                                _categories.removeAt(index);
                                await ref.read(configServiceProvider).saveCategories(_categories);
                                _load();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _categories.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
