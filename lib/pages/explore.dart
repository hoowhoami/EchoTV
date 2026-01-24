import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/douban_service.dart';
import '../widgets/zen_ui.dart';
import '../models/movie.dart';
import 'video_detail.dart';

final exploreMoviesProvider = FutureProvider.family<List<DoubanSubject>, Map<String, dynamic>>((ref, params) async {
  final service = ref.watch(doubanServiceProvider);
  final type = params['type'] as String;
  return service.getRexxarList(type == 'anime' ? 'tv' : type, '热门', '全部');
});

class ExplorePage extends ConsumerWidget {
  final String title;
  final String type;

  const ExplorePage({Key? key, required this.title, required this.type}) : super(key: key);

  void _handleMovieTap(BuildContext context, DoubanSubject movie) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => VideoDetailPage(subject: movie),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(exploreMoviesProvider({'type': type}));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            expandedHeight: 100,
            floating: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: Text(
                title,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
              ),
            ),
          ),
          
          movies.when(
            data: (items) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 24,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => MovieCard(
                    movie: items[index],
                    onTap: () => _handleMovieTap(context, items[index]),
                  ),
                  childCount: items.length,
                ),
              ),
            ),
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => SliverToBoxAdapter(
              child: Center(child: Text('Error: $err', style: TextStyle(color: Theme.of(context).colorScheme.primary))),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
