import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/douban_service.dart';
import '../services/config_service.dart';
import '../services/update_service.dart';
import '../providers/history_provider.dart';
import '../models/movie.dart';
import '../models/site.dart';
import '../widgets/zen_ui.dart';
import '../widgets/cover_image.dart';
import 'video_detail.dart';
import 'package:go_router/go_router.dart';

final hotMoviesProvider = FutureProvider<List<DoubanSubject>>((ref) async {
  final service = ref.watch(doubanServiceProvider);
  return service.getRexxarList('movie', '热门', '全部', count: 12);
});

final hotTvShowsProvider = FutureProvider<List<DoubanSubject>>((ref) async {
  final service = ref.watch(doubanServiceProvider);
  return service.getRexxarList('tv', 'tv', 'tv', count: 12);
});

final hotVarietyShowsProvider = FutureProvider<List<DoubanSubject>>((ref) async {
  final service = ref.watch(doubanServiceProvider);
  return service.getRexxarList('tv', 'show', 'show', count: 12);
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final Map<String, ScrollController> _scrollControllers = {};
  final Map<String, bool> _showLeftArrow = {};
  final Map<String, bool> _showRightArrow = {};
  
  static bool _hasCheckedUpdate = false;

  @override
  void initState() {
    super.initState();
    // 启动时自动检查更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCheckedUpdate) {
        _hasCheckedUpdate = true;
        UpdateService.checkUpdate(context);
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  ScrollController _getScrollController(String key) {
    if (!_scrollControllers.containsKey(key)) {
      final controller = ScrollController();
      controller.addListener(() {
        setState(() {
          _showLeftArrow[key] = controller.offset > 0;
          _showRightArrow[key] = controller.offset < controller.position.maxScrollExtent - 10;
        });
      });
      _scrollControllers[key] = controller;
      _showLeftArrow[key] = false;
      _showRightArrow[key] = true;
    }
    return _scrollControllers[key]!;
  }

  void _handleMovieTap(BuildContext context, DoubanSubject movie) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => VideoDetailPage(subject: movie),
    ));
  }

  Widget _buildSection(BuildContext context, String title, String route, String key, AsyncValue<List<DoubanSubject>> data) {
    final scrollController = _getScrollController(key);
    final showLeft = _showLeftArrow[key] ?? false;
    final showRight = _showRightArrow[key] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              GestureDetector(
                onTap: () => context.go(route),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Text('查看更多', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 12)),
                      Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.secondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 260, // 增加高度以适应 MovieCard 的内容（图片210px + 间距和文本约40px）
          child: data.maybeWhen(
            skipLoadingOnReload: true,
            skipLoadingOnRefresh: true,
            data: (movies) => Stack(
              children: [
                ListView.builder(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: movies.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 140,
                      margin: EdgeInsets.only(right: index < movies.length - 1 ? 16 : 0),
                      child: MovieCard(
                        movie: movies[index],
                        onTap: () => _handleMovieTap(context, movies[index]),
                      ),
                    );
                  },
                ),
                if (showLeft)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 40,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          scrollController.animateTo(
                            scrollController.offset - 400,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showRight)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 40,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          scrollController.animateTo(
                            scrollController.offset + 400,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            loading: () => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Container(
                  width: 140,
                  margin: EdgeInsets.only(right: index < 7 ? 16 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 2 / 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueWatching(BuildContext context, List<PlayRecord> history) {
    if (history.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('继续观看', style: Theme.of(context).textTheme.titleLarge),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('清空历史'),
                      content: const Text('确定要清空所有观看记录吗？'),
                      actions: [
                        ZenButton(
                          isSecondary: true,
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                        ZenButton(
                          backgroundColor: Colors.redAccent,
                          onPressed: () {
                            ref.read(historyProvider.notifier).clearHistory();
                            Navigator.pop(context);
                          },
                          child: const Text('清空'),
                        ),
                      ],
                    ),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    '清空',
                    style: TextStyle(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110, // 略微压缩高度，更精致
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            physics: const BouncingScrollPhysics(),
            itemCount: history.length,
            itemBuilder: (context, index) {
              return _ContinueWatchingCard(record: history[index]);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hotMovies = ref.watch(hotMoviesProvider);
    final hotTvShows = ref.watch(hotTvShowsProvider);
    final hotVarietyShows = ref.watch(hotVarietyShowsProvider);
    final playHistory = ref.watch(historyProvider);

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPC = screenWidth > 800;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            floating: true,
            toolbarHeight: isPC ? 20 : 56, // PC端大幅压缩标题栏高度
            title: isPC ? null : Text(
              'ECHOTV',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            actions: [
              if (!isPC) ...[
                IconButton(
                  onPressed: () => context.push('/search'),
                  icon: const Icon(LucideIcons.search, size: 20),
                ),
                IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(LucideIcons.settings, size: 20),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                if (!isPC) const SizedBox(height: 8) else const SizedBox(height: 24),
                playHistory.maybeWhen(
                  data: (history) => _buildContinueWatching(context, history),
                  orElse: () => const SizedBox.shrink(),
                ),
                if (playHistory.value?.isNotEmpty ?? false) const SizedBox(height: 24),
                _buildSection(context, '热门电影', '/movies', 'movies', hotMovies),
                const SizedBox(height: 24),
                _buildSection(context, '热门剧集', '/series', 'series', hotTvShows),
                const SizedBox(height: 24),
                _buildSection(context, '热门综艺', '/variety', 'variety', hotVarietyShows),
                const SizedBox(height: 32), // 底部留白大幅减少
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWatchingCard extends ConsumerStatefulWidget {
  final PlayRecord record;
  const _ContinueWatchingCard({required this.record});

  @override
  ConsumerState<_ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends ConsumerState<_ContinueWatchingCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = record.totalTime > 0 ? record.playTime / record.totalTime : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 16),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                final subject = DoubanSubject(
                  id: '',
                  title: record.searchTitle,
                  rate: '0.0',
                  cover: record.cover,
                  year: record.year,
                );
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => VideoDetailPage(subject: subject),
                ));
              },
              child: ZenGlassContainer(
                borderRadius: 18,
                blur: 30,
                child: Stack(
                  children: [
                    // 背景微弱氛围
                    Positioned(
                      right: -20,
                      top: -20,
                      bottom: -20,
                      width: 140,
                      child: Opacity(
                        opacity: 0.1,
                        child: CoverImage(
                          imageUrl: record.cover,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        // 左侧封面
                        SizedBox(
                          width: 74,
                          height: 110,
                          child: CoverImage(
                            imageUrl: record.cover,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // 右侧信息
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  record.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '观看至第 ${record.index + 1} 集',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.secondary.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // 胶囊式进度条容器
                                Container(
                                  height: 4,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progress.clamp(0.01, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                            blurRadius: 4,
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${(progress * 100).toInt()}% 已观看',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 删除按钮
            if (_isHovered)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    ref.read(historyProvider.notifier).removeRecord(record.searchTitle);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
