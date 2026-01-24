import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/config_service.dart';
import '../models/site.dart';
import '../widgets/zen_ui.dart';

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

  void _addSite() {
    final nameController = TextEditingController();
    final apiController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('添加视频源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: '名称')),
            TextField(controller: apiController, decoration: const InputDecoration(labelText: 'API 地址')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (apiController.text.isNotEmpty) {
                final newSite = SiteConfig(
                  key: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.isEmpty ? '新站点' : nameController.text,
                  api: apiController.text,
                );
                _sites.add(newSite);
                await ref.read(configServiceProvider).saveSites(_sites);
                _load();
                Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频源管理', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(onPressed: _addSite, icon: const Icon(Icons.add)),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _sites.length,
        itemBuilder: (context, index) {
          final site = _sites[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: ZenGlassContainer(
              borderRadius: 20,
              blur: 10,
              child: ListTile(
                title: Text(site.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(site.api, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    _sites.removeAt(index);
                    await ref.read(configServiceProvider).saveSites(_sites);
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
