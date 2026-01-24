import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/config_service.dart';
import '../models/live.dart';
import '../widgets/zen_ui.dart';

class LiveManagePage extends ConsumerStatefulWidget {
  const LiveManagePage({Key? key}) : super(key: key);

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

  void _addSource() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('添加直播源'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '源名称'),
            ),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'M3U URL'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && urlController.text.isNotEmpty) {
                final newSource = LiveSource(
                  key: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  url: urlController.text,
                );
                _sources.add(newSource);
                await ref.read(configServiceProvider).saveLiveSources(_sources);
                _load();
                Navigator.pop(context);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('直播源管理', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(onPressed: _addSource, icon: const Icon(Icons.add)),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _sources.length,
        itemBuilder: (context, index) {
          final source = _sources[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: ZenGlassContainer(
              borderRadius: 20,
              blur: 10,
              child: ListTile(
                title: Text(source.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(source.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () async {
                    _sources.removeAt(index);
                    await ref.read(configServiceProvider).saveLiveSources(_sources);
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