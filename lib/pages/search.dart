import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cms_service.dart';
import '../services/config_service.dart';
import '../models/site.dart';
import '../models/movie.dart';
import '../widgets/zen_ui.dart';
import '../providers/settings_provider.dart';
import 'video_detail.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<VideoDetail> _results = [];
  Map<String, List<VideoDetail>> _aggregatedResults = {};
  List<String> _history = [];
  
  bool _isLoading = false;
  bool _isSearching = false;
  bool _noSitesConfigured = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _controller.addListener(() {
      if (_controller.text.isEmpty && _isSearching) {
        setState(() {
          _isSearching = false;
          _results = [];
          _aggregatedResults = {};
          _noSitesConfigured = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveHistory(String query) async {
    if (query.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _history.remove(query);
    _history.insert(0, query);
    if (_history.length > 15) _history = _history.sublist(0, 15);
    await prefs.setStringList('search_history', _history);
    setState(() {});
  }

  Future<void> _deleteHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    _history.remove(query);
    await prefs.setStringList('search_history', _history);
    setState(() {});
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
    setState(() => _history = []);
  }

  void _handleSearch([String? query]) async {
    final searchText = query ?? _controller.text.trim();
    if (searchText.isEmpty) return;
    
    if (query != null) _controller.text = query;
    _focusNode.unfocus();
    
    setState(() {
      _isLoading = true;
      _isSearching = true;
      _results = [];
      _noSitesConfigured = false;
    });

    _saveHistory(searchText);

    final cmsService = ref.read(cmsServiceProvider);
    final configService = ref.read(configServiceProvider);
    final sites = await configService.getSites();
    final activeSites = sites.where((s) => !s.disabled).toList();

    if (activeSites.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _noSitesConfigured = true;
        });
      }
      return;
    }

    await for (final allResults in cmsService.searchAllStream(activeSites, searchText)) {
      if (!mounted) break;
      final filteredResults = _filterAndSortResults(allResults, searchText);
      
      // 聚合逻辑：按标题、年份和类型（集数）分组
      final aggregated = <String, List<VideoDetail>>{};
      for (var result in filteredResults) {
        final key = '${result.title.replaceAll(' ', '')}-${result.year ?? '未知'}-${result.playGroups.first.urls.length > 1 ? 'tv' : 'movie'}';
        if (!aggregated.containsKey(key)) aggregated[key] = [];
        aggregated[key]!.add(result);
      }

      setState(() {
        _results = filteredResults;
        _aggregatedResults = aggregated;
        _isLoading = false;
      });
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<VideoDetail> _filterAndSortResults(List<VideoDetail> results, String query) {
    final q = query.replaceAll(' ', '').toLowerCase();
    return results.where((res) => res.title.replaceAll(' ', '').toLowerCase().contains(q)).toList()
      ..sort((a, b) {
        final aExact = a.title.replaceAll(' ', '').toLowerCase() == q;
        final bExact = b.title.replaceAll(' ', '').toLowerCase() == q;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
        final aY = int.tryParse(a.year ?? '0') ?? 0;
        final bY = int.tryParse(b.year ?? '0') ?? 0;
        return bY.compareTo(aY);
      });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPC = screenWidth > 800;
    final horizontalPadding = isPC ? 48.0 : 24.0;
    
    // 监听设置状态
    final isAggregate = ref.watch(aggregateSearchProvider);

    final availableWidth = screenWidth - (isPC ? 240 : 0) - (horizontalPadding * 2);
    final crossAxisCount = availableWidth > 800 ? 5 : (availableWidth > 600 ? 4 : (availableWidth > 400 ? 3 : 2));

    return ZenScaffold(
      body: CustomScrollView(
        slivers: [
          const ZenSliverAppBar(
            title: '搜索',
            subtitle: '探索海量影视资源',
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 0),
              child: _buildSearchBar(theme),
            ),
          ),
          // 搜索状态栏：显示总数和聚合开关
          if (_isSearching && _results.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 8),
                child: Row(
                  children: [
                    Text(
                      '共找到 ${_results.length} 个资源',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.secondary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '聚合',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Transform.scale(
                          scale: 0.8,
                          child: ZenSwitch(
                            value: isAggregate,
                            onChanged: (val) => ref.read(aggregateSearchProvider.notifier).setEnabled(val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          if (!_isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                child: _buildHistorySection(theme),
              ),
            )
          else if (_isLoading && _results.isEmpty)
            _buildSkeletonGrid(horizontalPadding, crossAxisCount)
          else if (_isSearching && _results.isEmpty && !_isLoading)
            _buildEmptyState(theme)
          else ...[
            if (isAggregate)
              _buildAggregatedGrid(_aggregatedResults, horizontalPadding, crossAxisCount)
            else
              ..._buildGroupedSlivers(_results, horizontalPadding, crossAxisCount),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildAggregatedGrid(Map<String, List<VideoDetail>> aggregated, double padding, int crossAxisCount) {
    final entries = aggregated.values.toList();
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.53,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final group = entries[index];
            final representative = group.first;
            return _buildMovieCard(representative, badge: '${group.length} 源');
          },
          childCount: entries.length,
        ),
      ),
    );
  }

  List<Widget> _buildGroupedSlivers(List<VideoDetail> results, double padding, int crossAxisCount) {
    final widgets = <Widget>[];
    
    // 按来源名称分组
    final Map<String, List<VideoDetail>> groupedBySource = {};
    for (var result in results) {
      final sourceName = result.sourceName;
      if (!groupedBySource.containsKey(sourceName)) {
        groupedBySource[sourceName] = [];
      }
      groupedBySource[sourceName]!.add(result);
    }

    // 按来源名称排序
    final sortedKeys = groupedBySource.keys.toList()..sort();
    
    for (var source in sortedKeys) {
      final items = groupedBySource[source]!;
      // 来源标题栏
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(padding, 24, padding, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1), 
                    borderRadius: BorderRadius.circular(6)
                  ),
                  child: Text(
                    source, 
                    style: TextStyle(
                      color: Theme.of(context).primaryColor, 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length} 个结果', 
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary, 
                    fontSize: 11
                  )
                ),
              ],
            ),
          ),
        ),
      );
      
      // 该来源下的资源网格
      widgets.add(
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.53,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildMovieCard(items[index]),
              childCount: items.length,
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 14),
          Icon(LucideIcons.search, size: 18, color: theme.colorScheme.secondary.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onSubmitted: (val) => _handleSearch(),
              style: const TextStyle(fontSize: 15, decoration: TextDecoration.none),
              decoration: InputDecoration(
                hintText: '搜索电影、剧集、综艺...',
                hintStyle: TextStyle(color: theme.colorScheme.secondary.withValues(alpha: 0.5), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  _controller.clear();
                  setState(() => _isSearching = false);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(LucideIcons.xCircle, size: 16, color: theme.colorScheme.secondary.withValues(alpha: 0.6)),
                ),
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildHistorySection(ThemeData theme) {
    if (_history.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('最近搜索', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton(
                onPressed: _clearHistory,
                child: Text('清空', style: TextStyle(color: theme.colorScheme.secondary, fontSize: 12)),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _history.map((q) => _buildHistoryChip(theme, q)).toList(),
        ),
      ],
    );
  }

  Widget _buildHistoryChip(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _handleSearch(text),
              child: Text(text, style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _deleteHistory(text),
              child: Icon(LucideIcons.x, size: 12, color: theme.colorScheme.secondary.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid(double padding, int count) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: count,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.53,
        ),
        delegate: SliverChildBuilderDelegate((c, i) => _buildSkeletonCard(Theme.of(c)), childCount: 10),
      ),
    );
  }

  Widget _buildMovieCard(VideoDetail item, {String? badge}) {
    final subject = DoubanSubject(id: item.id, title: item.title, rate: '0.0', cover: item.poster, year: item.year);
    return MovieCard(
      movie: subject, 
      badge: badge,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => VideoDetailPage(subject: subject)))
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Icon(
              _noSitesConfigured ? LucideIcons.alertCircle : LucideIcons.searchX, 
              size: 48, 
              color: theme.colorScheme.secondary.withValues(alpha: 0.3)
            ),
            const SizedBox(height: 16),
            Text(
              _noSitesConfigured ? '未配置有效视频源' : '未搜到匹配资源', 
              style: TextStyle(color: theme.colorScheme.secondary)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard(ThemeData theme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: -2.0, end: 2.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ],
              stops: [(value - 1).clamp(0.0, 1.0), value.clamp(0.0, 1.0), (value + 1).clamp(0.0, 1.0)],
            ).createShader(bounds);
          },
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }
}
