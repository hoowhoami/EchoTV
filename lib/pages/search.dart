import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  List<VideoDetail> _results = [];
  bool _isLoading = false;

  // 按源分组的结果
  Map<String, List<VideoDetail>> _groupedResults = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSearch() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
      _groupedResults = {};
    });

    final cmsService = ref.read(cmsServiceProvider);
    final configService = ref.read(configServiceProvider);
    final sites = await configService.getSites();

    final searchQuery = _controller.text.trim();

    // 使用流式搜索：只要有结果就立即展示
    await for (final allResults in cmsService.searchAllStream(sites, searchQuery)) {
      if (!mounted) break;

      // 过滤和排序结果
      final filteredResults = _filterAndSortResults(allResults, searchQuery);

      // 按源分组
      final grouped = <String, List<VideoDetail>>{};
      for (var result in filteredResults) {
        final sourceName = result.sourceName;
        if (!grouped.containsKey(sourceName)) {
          grouped[sourceName] = [];
        }
        grouped[sourceName]!.add(result);
      }

      setState(() {
        _results = filteredResults;
        _groupedResults = grouped;
        _isLoading = false; // 只要有第一个结果就结束加载状态
      });
    }

    // 流结束后确保加载状态关闭
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 过滤和排序搜索结果
  /// 参考 LunaTV 的排序逻辑：完全匹配优先，年份倒序，未知年份最后
  List<VideoDetail> _filterAndSortResults(List<VideoDetail> results, String query) {
    final normalizedQuery = query.replaceAll(' ', '').toLowerCase();

    return results.where((result) {
      // 基本过滤：标题必须包含搜索关键词（忽略空格和大小写）
      final normalizedTitle = result.title.replaceAll(' ', '').toLowerCase();
      return normalizedTitle.contains(normalizedQuery);
    }).toList()
      ..sort((a, b) {
        // 1. 完全匹配标题优先
        final aExact = a.title.replaceAll(' ', '').toLowerCase() == normalizedQuery;
        final bExact = b.title.replaceAll(' ', '').toLowerCase() == normalizedQuery;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;

        // 2. 年份排序：有效年份优先，按年份倒序
        final aYear = a.year;
        final bYear = b.year;

        final aHasYear = aYear != null && aYear.isNotEmpty && aYear != 'unknown';
        final bHasYear = bYear != null && bYear.isNotEmpty && bYear != 'unknown';

        if (aHasYear && !bHasYear) return -1;
        if (!aHasYear && bHasYear) return 1;

        if (aHasYear && bHasYear) {
          final aYearNum = int.tryParse(aYear) ?? 0;
          final bYearNum = int.tryParse(bYear) ?? 0;
          return bYearNum.compareTo(aYearNum); // 年份倒序
        }

        return 0;
      });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const pagePadding = 24.0;
    const gridSpacing = 16.0;
    // 调整宽高比，为文本和间距预留空间
    // 图片占 2:3，文本约需 50px，所以整体宽高比要小于 2/3
    const posterAspectRatio = 0.53;

    // 获取屏幕宽度（减去左右内边距）
    final screenWidth = MediaQuery.of(context).size.width - 2 * pagePadding;

    // 根据屏幕宽度决定列数
    final crossAxisCount = screenWidth > 600
        ? 4  // 平板/大屏手机
        : screenWidth > 400
            ? 3  // 普通手机横屏/大屏手机
            : 2; // 小屏手机

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            floating: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _handleSearch(),
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索电影、剧集...',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.secondary, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading && _results.isEmpty)
            // 骨架屏幕
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: gridSpacing,
                  mainAxisSpacing: 24,
                  childAspectRatio: posterAspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildSkeletonCard(theme),
                  childCount: 12, // 显示 12 个骨架卡片
                ),
              ),
            )
          else if (_groupedResults.isNotEmpty)
            // 按源分组展示
            ..._buildGroupedResults(crossAxisCount, gridSpacing, posterAspectRatio)
          else if (_results.isNotEmpty)
            // 兜底：如果没有分组数据但有结果，使用原来的展示方式
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: gridSpacing,
                  mainAxisSpacing: 24,
                  childAspectRatio: posterAspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _results[index];
                    return _buildMovieCard(item);
                  },
                  childCount: _results.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  /// 构建按源分组的结果列表
  List<Widget> _buildGroupedResults(int crossAxisCount, double gridSpacing, double posterAspectRatio) {
    final widgets = <Widget>[];

    // 按源名称排序
    final sortedSources = _groupedResults.keys.toList()..sort();

    for (var sourceName in sortedSources) {
      final sourceResults = _groupedResults[sourceName]!;

      // 源标题
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    sourceName,
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${sourceResults.length} 个结果',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // 源的结果网格
      widgets.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: gridSpacing,
              mainAxisSpacing: 24,
              childAspectRatio: posterAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = sourceResults[index];
                return _buildMovieCard(item);
              },
              childCount: sourceResults.length,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  /// 构建单个电影卡片
  Widget _buildMovieCard(VideoDetail item) {
    final subject = DoubanSubject(
      id: item.id,
      title: item.title,
      rate: '0.0',
      cover: item.poster,
      year: item.year,
    );
    return MovieCard(
      movie: subject,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoDetailPage(subject: subject),
        ),
      ),
    );
  }

  /// 构建骨架卡片
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
              stops: [
                (value - 1).clamp(0.0, 1.0),
                value.clamp(0.0, 1.0),
                (value + 1).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 骨架图片
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                  ),
                ),
                // 骨架文本
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        // 动画结束后重新开始
        if (mounted) {
          setState(() {});
        }
      },
    );
  }
}