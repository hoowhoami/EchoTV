import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/config_service.dart';
import '../models/site.dart';
import '../widgets/zen_ui.dart';

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
    final categories = await ref.read(configServiceProvider).getCategories();
    setState(() => _categories = categories);
  }

  void _addCategory() {
    final nameController = TextEditingController();
    final queryController = TextEditingController();
    String type = 'movie';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: const Text('添加分类'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '显示名称 (可选)'),
              ),
              TextField(
                controller: queryController,
                decoration: const InputDecoration(labelText: '查询关键字'),
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: type,
                isExpanded: true,
                onChanged: (val) => setDialogState(() => type = val!),
                items: const [
                  DropdownMenuItem(value: 'movie', child: Text('电影')),
                  DropdownMenuItem(value: 'tv', child: Text('剧集')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                if (queryController.text.isNotEmpty) {
                  final newCat = CustomCategory(
                    name: nameController.text.isEmpty ? null : nameController.text,
                    type: type,
                    query: queryController.text,
                  );
                  _categories.add(newCat);
                  await ref.read(configServiceProvider).saveCategories(_categories);
                  _load();
                  Navigator.pop(context);
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(onPressed: _addCategory, icon: const Icon(Icons.add)),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: ZenGlassContainer(
              borderRadius: 20,
              blur: 10,
              child: ListTile(
                leading: Icon(cat.type == 'movie' ? Icons.movie : Icons.tv),
                title: Text(cat.name ?? cat.query, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('查询: ${cat.query} • 类型: ${cat.type == 'movie' ? "电影" : "剧集"}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    _categories.removeAt(index);
                    await ref.read(configServiceProvider).saveCategories(_categories);
                    _load();
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
