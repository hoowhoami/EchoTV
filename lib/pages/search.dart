import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cms_service.dart';
import '../services/config_service.dart';
import '../models/site.dart';
import '../models/movie.dart';
import '../widgets/zen_ui.dart';
import 'video_detail.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<VideoDetail> _results = [];
  Map<String, List<VideoDetail>> _groupedResults = {};
  List<String> _history = [];
  
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _controller.addListener(() {
      if (_controller.text.isEmpty && _isSearching) {
        setState(() {
          _isSearching = false;
          _results = [];
          _groupedResults = {};
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
      _groupedResults = {};
    });

    _saveHistory(searchText);

    final cmsService = ref.read(cmsServiceProvider);
    final configService = ref.read(configServiceProvider);
    final sites = await configService.getSites();

    await for (final allResults in cmsService.searchAllStream(sites, searchText)) {
      if (!mounted) break;
      final filteredResults = _filterAndSortResults(allResults, searchText);
      final grouped = <String, List<VideoDetail>>{};
      for (var result in filteredResults) {
        final sourceName = result.sourceName;
        if (!grouped.containsKey(sourceName)) grouped[sourceName] = [];
        grouped[sourceName]!.add(result);
      }
      setState(() {
        _results = filteredResults;
        _groupedResults = grouped;
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
    
    final availableWidth = screenWidth - (isPC ? 240 : 0) - (horizontalPadding * 2);
    final crossAxisCount = availableWidth > 800 ? 5 : (availableWidth > 600 ? 4 : (availableWidth > 400 ? 3 : 2));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          const ZenSliverAppBar(
            title: '搜索',
            subtitle: '探索海量影视资源',
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 4, horizontalPadding, 16),
              child: _buildSearchBar(theme),
            ),
          ),
          if (!_isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildHistorySection(theme),
              ),
            )
          else if (_isLoading && _results.isEmpty)
            _buildSkeletonGrid(horizontalPadding, crossAxisCount)
          else if (_groupedResults.isNotEmpty)
            ..._buildGroupedSlivers(horizontalPadding, crossAxisCount)
          else if (!_isLoading && _isSearching && _results.isEmpty)
            _buildEmptyState(theme),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
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
            GestureDetector(
              onTap: () {
                _controller.clear();
                setState(() => _isSearching = false);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(LucideIcons.xCircle, size: 16, color: theme.colorScheme.secondary.withValues(alpha: 0.6)),
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
            TextButton(
              onPressed: _clearHistory,
              child: Text('清空', style: TextStyle(color: theme.colorScheme.secondary, fontSize: 12)),
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
          GestureDetector(
            onTap: () => _handleSearch(text),
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _deleteHistory(text),
            child: Icon(LucideIcons.x, size: 12, color: theme.colorScheme.secondary.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedSlivers(double padding, int crossAxisCount) {
    final widgets = <Widget>[];
    final sortedKeys = _groupedResults.keys.toList()..sort();
    for (var source in sortedKeys) {
      final items = _groupedResults[source]!;
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(padding, 24, padding, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(source, style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('${items.length} 个结果', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 11)),
              ],
            ),
          ),
        ),
      );
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

  Widget _buildMovieCard(VideoDetail item) {
    final subject = DoubanSubject(id: item.id, title: item.title, rate: '0.0', cover: item.poster, year: item.year);
    return MovieCard(movie: subject, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => VideoDetailPage(subject: subject))));
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Icon(LucideIcons.searchX, size: 48, color: theme.colorScheme.secondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('未搜到匹配资源', style: TextStyle(color: theme.colorScheme.secondary)),
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