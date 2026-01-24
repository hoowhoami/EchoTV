import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/douban_service.dart';
import '../widgets/zen_ui.dart';
import '../models/movie.dart';
import 'video_detail.dart';
import 'package:go_router/go_router.dart';

final hotMoviesProvider = FutureProvider<List<DoubanSubject>>((ref) async {
  final service = ref.watch(doubanServiceProvider);
  return service.getRexxarList('movie', '热门', '全部');
});

class HomePage extends ConsumerWidget {
  const HomePage({Key? key}) : super(key: key);

  void _handleMovieTap(BuildContext context, DoubanSubject movie) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => VideoDetailPage(subject: movie),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotMovies = ref.watch(hotMoviesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            expandedHeight: 120,
            floating: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: Text(
                'ECHOTV',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => context.go('/settings'), 
                icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.primary)
              ),
              const SizedBox(width: 16),
            ],
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                '最近热门',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          
          hotMovies.when(
            data: (movies) => SliverPadding(
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
                    movie: movies[index],
                    onTap: () => _handleMovieTap(context, movies[index]),
                  ),
                  childCount: movies.length,
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
