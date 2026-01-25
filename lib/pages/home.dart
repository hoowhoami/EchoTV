import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/douban_service.dart';
import '../models/movie.dart';
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
                child: Row(
                  children: [
                    Text('查看更多', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 12)),
                    Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.secondary),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: data.when(
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
                      width: 160,
                      margin: EdgeInsets.only(right: index < movies.length - 1 ? 16 : 0),
                      child: GestureDetector(
                        onTap: () => _handleMovieTap(context, movies[index]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: movies[index].cover,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(child: Icon(Icons.error, color: Colors.grey)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              movies[index].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '⭐ ${movies[index].rate}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
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
                  width: 160,
                  margin: EdgeInsets.only(right: index < 7 ? 16 : 0),
                  child: Column(
                    children: [
                      Expanded(
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
            error: (err, stack) => Center(child: Text('Error: $err')),
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isPC = screenWidth > 800;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            floating: true,
            title: Text(
              'ECHOTV',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: isPC ? 28 : 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildSection(context, '热门电影', '/movies', 'movies', hotMovies),
                const SizedBox(height: 24),
                _buildSection(context, '热门剧集', '/series', 'series', hotTvShows),
                const SizedBox(height: 24),
                _buildSection(context, '热门综艺', '/variety', 'variety', hotVarietyShows),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
