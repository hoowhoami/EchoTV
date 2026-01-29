import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../services/douban_service.dart';
import '../widgets/zen_ui.dart';
import '../widgets/douban_selector.dart';
import '../models/movie.dart';
import 'video_detail.dart';

class ExplorePage extends ConsumerStatefulWidget {
  final String title;
  final String type;

  const ExplorePage({super.key, required this.title, required this.type});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  late String primarySelection;
  late String secondarySelection;
  Map<String, String> multiLevelFilters = {};

  List<DoubanSubject> movies = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  int currentPage = 0;


  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 根据类型设置默认选择
    if (widget.type == 'movie') {
      primarySelection = '热门';
      secondarySelection = '全部';
    } else if (widget.type == 'tv') {
      primarySelection = '最近热门';
      secondarySelection = 'tv';
    } else if (widget.type == 'show') {
      primarySelection = '最近热门';
      secondarySelection = 'show';
    } else if (widget.type == 'anime') {
      primarySelection = '番剧';
      secondarySelection = '';
    } else {
      primarySelection = '热门';
      secondarySelection = '全部';
    }

    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      if (!isLoadingMore && hasMore) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadData() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
      movies = [];
      currentPage = 0;
      hasMore = true;
    });

    final service = ref.read(doubanServiceProvider);
    final data = await _fetchData(service, 0);

    if (mounted) {
      setState(() {
        movies = data;
        isLoading = false;
        hasMore = data.isNotEmpty;
      });
    }
  }

  Future<void> _loadMoreData() async {
    if (isLoadingMore || !hasMore) return;

    setState(() {
      isLoadingMore = true;
    });

    final service = ref.read(doubanServiceProvider);
    final nextPage = currentPage + 1;
    final data = await _fetchData(service, nextPage);

    if (mounted) {
      setState(() {
        if (data.isNotEmpty) {
          movies.addAll(data);
          currentPage = nextPage;
          hasMore = data.isNotEmpty;
        } else {
          hasMore = false;
        }
        isLoadingMore = false;
      });
    }
  }

  Future<List<DoubanSubject>> _fetchData(DoubanService service, int page) async {
    final pageStart = page * 24;
    final multiLevel = _encodeMultiLevelFilters();

    // 电影
    if (widget.type == 'movie') {
      if (primarySelection == '全部') {
        final filters = <String, String>{};
        if (multiLevel.isNotEmpty) {
          final filterParts = multiLevel.split(',');
          for (var part in filterParts) {
            final kv = part.split('=');
            if (kv.length == 2 && kv[1] != 'all' && kv[1] != 'T') {
              filters[kv[0]] = kv[1];
            }
          }
        }
        return service.getRecommendList('movie', filters, pageStart: pageStart);
      } else {
        return service.getRexxarList('movie', primarySelection, secondarySelection, pageStart: pageStart);
      }
    }

    // 剧集
    else if (widget.type == 'tv') {
      if (primarySelection == '全部') {
        final filters = <String, String>{'format': '电视剧'};
        if (multiLevel.isNotEmpty) {
          final filterParts = multiLevel.split(',');
          for (var part in filterParts) {
            final kv = part.split('=');
            if (kv.length == 2 && kv[1] != 'all' && kv[1] != 'T') {
              filters[kv[0]] = kv[1];
            }
          }
        }
        return service.getRecommendList('tv', filters, pageStart: pageStart);
      } else {
        return service.getRexxarList('tv', secondarySelection, secondarySelection, pageStart: pageStart);
      }
    }

    // 综艺
    else if (widget.type == 'show') {
      if (primarySelection == '全部') {
        final filters = <String, String>{'format': '综艺'};
        if (multiLevel.isNotEmpty) {
          final filterParts = multiLevel.split(',');
          for (var part in filterParts) {
            final kv = part.split('=');
            if (kv.length == 2 && kv[1] != 'all' && kv[1] != 'T') {
              filters[kv[0]] = kv[1];
            }
          }
        }
        return service.getRecommendList('tv', filters, pageStart: pageStart);
      } else {
        return service.getRexxarList('tv', secondarySelection, secondarySelection, pageStart: pageStart);
      }
    }

    // 动漫
    else if (widget.type == 'anime') {
      final filters = <String, String>{'category': '动画'};
      if (primarySelection == '番剧') {
        filters['format'] = '电视剧';
        return service.getRecommendList('tv', filters, pageStart: pageStart);
      } else {
        return service.getRecommendList('movie', filters, pageStart: pageStart);
      }
    }

    return service.getRexxarList('movie', '热门', '全部', pageStart: pageStart);
  }

  String _encodeMultiLevelFilters() {
    if (multiLevelFilters.isEmpty) return '';
    return multiLevelFilters.entries.map((e) => '${e.key}=${e.value}').join(',');
  }

  void _handleMovieTap(BuildContext context, DoubanSubject movie) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => VideoDetailPage(subject: movie),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const gridSpacing = 16.0;
    const posterAspectRatio = 0.53;

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 800 ? 48.0 : 24.0;
    final availableWidth = screenWidth - 2 * horizontalPadding;
    final isPC = screenWidth > 800;

    // 根据屏幕宽度决定列数
    final crossAxisCount = availableWidth > 600
        ? 4  // 平板/大屏手机
        : availableWidth > 400
            ? 3  // 普通手机横屏/大屏手机
            : 2; // 小屏手机

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            floating: true,
            expandedHeight: isPC ? 90 : 80,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: EdgeInsets.only(
                left: horizontalPadding, 
                right: horizontalPadding,
                bottom: 12,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: isPC ? 15 : 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1), // 极简间距
                  Text(
                    '来自豆瓣的精选内容',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!isPC) ...[
                IconButton(
                  onPressed: () => context.go('/search'),
                  icon: const Icon(LucideIcons.search, size: 20),
                ),
                IconButton(
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(LucideIcons.settings, size: 20),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),

          // 筛选器
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              child: DoubanSelector(
                type: widget.type,
                primarySelection: primarySelection,
                secondarySelection: secondarySelection,
                onPrimaryChange: (value) {
                  setState(() {
                    primarySelection = value;
                    multiLevelFilters = {};
                    // 重置二级选择
                    if (widget.type == 'movie') {
                      secondarySelection = '全部';
                    } else if (widget.type == 'tv') {
                      secondarySelection = 'tv';
                    } else if (widget.type == 'show') {
                      secondarySelection = 'show';
                    }
                  });
                  _loadData();
                },
                onSecondaryChange: (value) {
                  setState(() {
                    secondarySelection = value;
                  });
                  _loadData();
                },
                onMultiLevelChange: (values) {
                  setState(() {
                    multiLevelFilters = values;
                  });
                  _loadData();
                },
              ),
            ),
          ),

          if (isLoading)
            // 骨架屏幕
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: gridSpacing,
                  mainAxisSpacing: 24,
                  childAspectRatio: posterAspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildSkeletonCard(Theme.of(context)),
                  childCount: 12, // 显示 12 个骨架卡片
                ),
              ),
            )
          else if (movies.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Text('暂无内容', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: gridSpacing,
                  mainAxisSpacing: 24,
                  childAspectRatio: posterAspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => MovieCard(
                    movie: movies[index],
                    onTap: () => _handleMovieTap(context, movies[index]),
                  ),
                  childCount: movies.length,
                ),
              ),
            ),

          if (isLoadingMore)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          if (!hasMore && movies.isNotEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('已加载全部内容', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
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
