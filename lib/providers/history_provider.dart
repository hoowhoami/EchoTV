import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/site.dart';
import '../services/config_service.dart';

final historyProvider = NotifierProvider<HistoryNotifier, AsyncValue<List<PlayRecord>>>(HistoryNotifier.new);

class HistoryNotifier extends Notifier<AsyncValue<List<PlayRecord>>> {
  @override
  AsyncValue<List<PlayRecord>> build() {
    _loadHistory();
    return const AsyncLoading();
  }

  Future<void> _loadHistory() async {
    final service = ref.read(configServiceProvider);
    try {
      final history = await service.getHistory();
      state = AsyncData(history);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> saveRecord(PlayRecord record) async {
    final service = ref.read(configServiceProvider);
    
    // 获取当前列表并更新
    final currentHistory = state.value ?? [];
    final updatedHistory = List<PlayRecord>.from(currentHistory);
    
    updatedHistory.removeWhere((r) => r.searchTitle == record.searchTitle);
    updatedHistory.insert(0, record);
    if (updatedHistory.length > 20) updatedHistory.removeLast();
    
    // 先更新 UI 状态，实现秒开感
    state = AsyncData(updatedHistory);
    
    // 异步持久化
    await service.saveHistory(updatedHistory);
  }

  Future<void> clearHistory() async {
    final service = ref.read(configServiceProvider);
    state = const AsyncData([]);
    await service.saveHistory([]);
  }

  Future<void> removeRecord(String searchTitle) async {
    final service = ref.read(configServiceProvider);
    final currentHistory = state.value ?? [];
    final updatedHistory = currentHistory.where((r) => r.searchTitle != searchTitle).toList();
    
    state = AsyncData(updatedHistory);
    await service.saveHistory(updatedHistory);
  }
}
