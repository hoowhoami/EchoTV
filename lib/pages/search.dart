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

  void _handleSearch() async {
    if (_controller.text.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _results = [];
    });

    final cmsService = ref.read(cmsServiceProvider);
    final configService = ref.read(configServiceProvider);
    final sites = await configService.getSites();

    final allResults = await cmsService.searchAll(sites, _controller.text);

    if (mounted) {
      setState(() {
        _results = allResults;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.white.withOpacity(0.1),
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
          
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else
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
                    // 将 VideoDetail 转换为 DoubanSubject 以适配 MovieCard
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
}