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
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 24,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = _results[index];
                    return GestureDetector(
                      onTap: () async {
                        // 将 VideoDetail 臨時转换为 DoubanSubject 以适配详情页
                        final subject = DoubanSubject(
                          id: item.id,
                          title: item.title,
                          rate: '0.0',
                          cover: item.poster,
                          year: item.year,
                        );
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => VideoDetailPage(subject: subject),
                        ));
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: item.poster.isNotEmpty 
                                ? Image.network(item.poster, fit: BoxFit.cover, errorBuilder: (_,__,___) => Container(color: Colors.grey[900]))
                                : Container(color: Colors.grey[900]),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '${item.sourceName} • ${item.year ?? "未知"}',
                            style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 11),
                          ),
                        ],
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