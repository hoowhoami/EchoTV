import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/movie.dart';
import '../models/site.dart';
import '../services/cms_service.dart';
import '../services/douban_service.dart';
import '../services/config_service.dart';
import '../services/video_quality_service.dart';
import '../services/source_optimizer_service.dart';
import '../widgets/zen_ui.dart';

class VideoDetailPage extends ConsumerStatefulWidget {
  final DoubanSubject subject;

  const VideoDetailPage({Key? key, required this.subject}) : super(key: key);

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends ConsumerState<VideoDetailPage> with SingleTickerProviderStateMixin {
  DoubanSubject? _fullSubject;
  late TabController _tabController;

  List<VideoDetail> _availableSources = [];
  VideoDetail? _currentSource;
  int _currentEpisodeIndex = 0;
  bool _isSearching = true;
  bool _isOptimizing = false;

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isPlaying = false;

  // 质量信息缓存
  final Map<String, VideoQualityInfo> _qualityInfoMap = {};
  final Map<String, double> _scoreMap = {};
  final Set<String> _testedSources = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() async {
    final doubanService = ref.read(doubanServiceProvider);
    final cmsService = ref.read(cmsServiceProvider);
    final configService = ref.read(configServiceProvider);

    doubanService.getDetail(widget.subject.id).then((val) {
      if (mounted) setState(() => _fullSubject = val ?? widget.subject);
    });

    final sites = await configService.getSites();
    final results = await cmsService.searchAll(sites, widget.subject.title);

    // 宽松过滤逻辑：只要标题包含关键词即可
    final filtered = results.where((res) {
      final sTitle = res.title.replaceAll(' ', '').toLowerCase();
      final tTitle = widget.subject.title.replaceAll(' ', '').toLowerCase();

      // 双向匹配：源标题包含搜索词 或 搜索词包含源标题
      final match = sTitle.contains(tTitle) || tTitle.contains(sTitle);
      return match;
    }).toList();

    // 基础排序：完全匹配优先，集数多优先
    filtered.sort((a, b) {
      final aExact = a.title.replaceAll(' ', '').toLowerCase() == widget.subject.title.replaceAll(' ', '').toLowerCase();
      final bExact = b.title.replaceAll(' ', '').toLowerCase() == widget.subject.title.replaceAll(' ', '').toLowerCase();
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      return b.playGroups.first.urls.length.compareTo(a.playGroups.first.urls.length);
    });

    if (mounted) {
      setState(() {
        _availableSources = filtered;
        _isSearching = false;
        if (filtered.isNotEmpty) {
          _currentSource = filtered.first;
        }
      });

      // 自动优选最佳播放源
      if (filtered.length > 1) {
        _optimizeBestSource(filtered);
      }
    }
  }

  /// 自动优选最佳播放源
  Future<void> _optimizeBestSource(List<VideoDetail> sources) async {
    if (sources.isEmpty) return;

    setState(() => _isOptimizing = true);

    try {
      final optimizer = ref.read(sourceOptimizerServiceProvider);
      final result = await optimizer.selectBestSource(sources);

      if (mounted) {
        setState(() {
          _qualityInfoMap.addAll(result.qualityInfoMap);
          _scoreMap.addAll(result.scoreMap);
          _testedSources.addAll(result.qualityInfoMap.keys);
          _isOptimizing = false;

          // 如果当前未播放，自动切换到最佳源
          if (!_isPlaying) {
            _currentSource = result.bestSource;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOptimizing = false);
      }
    }
  }

  Future<void> _initializePlayer(String url, int index, {double? resumePosition}) async {
    await _videoController?.dispose();
    _chewieController?.dispose();

    setState(() {
      _isPlaying = true;
      _currentEpisodeIndex = index;
      _chewieController = null;
    });

    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();

      // 恢复播放进度（如果指定）
      if (resumePosition != null && resumePosition > 1) {
        await _videoController!.seekTo(Duration(seconds: resumePosition.toInt()));
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(playedColor: Colors.white, handleColor: Colors.white),
      );
    } catch (e) {
      // Player initialization failed
    }
    if (mounted) setState(() {});
  }

  /// 智能换源：尝试保持相同集数和播放进度
  Future<void> _switchSource(VideoDetail newSource) async {
    final oldEpisodeIndex = _currentEpisodeIndex;
    final oldPlayPosition = _videoController?.value.position.inSeconds.toDouble() ?? 0.0;

    setState(() {
      _currentSource = newSource;
    });

    // 尝试保持相同集数
    final newGroup = newSource.playGroups.first;
    int targetIndex = oldEpisodeIndex;

    // 如果新源的集数不够，跳到第一集
    if (targetIndex >= newGroup.urls.length) {
      targetIndex = 0;
    }

    // 如果正在播放，自动切换到新源的对应集数
    if (_isPlaying) {
      // 同集数时尝试恢复播放进度
      final resumePosition = (targetIndex == oldEpisodeIndex && oldPlayPosition > 1) ? oldPlayPosition : null;
      await _initializePlayer(newGroup.urls[targetIndex], targetIndex, resumePosition: resumePosition);
    } else {
      // 未播放时只更新集数索引
      setState(() {
        _currentEpisodeIndex = targetIndex;
      });
    }

    // 自动切换回选集 Tab
    _tabController.animateTo(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 📺 播放器
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  if (_isPlaying)
                    Center(
                      child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                          ? Chewie(controller: _chewieController!)
                          : const CircularProgressIndicator(color: Colors.white),
                    )
                  else
                    Positioned.fill(
                      child: Stack(
                        children: [
                          Positioned.fill(child: Image.network(widget.subject.cover, fit: BoxFit.cover)),
                          Container(color: Colors.black.withOpacity(0.6)),
                          Center(
                            child: _isSearching 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : _currentSource != null 
                                ? ZenButton(
                                    onPressed: () => _initializePlayer(_currentSource!.playGroups.first.urls[0], 0),
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    borderRadius: 50,
                                    padding: const EdgeInsets.all(20),
                                    child: const Icon(Icons.play_arrow_rounded, size: 40),
                                  )
                                : const Text('未找到资源', style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    top: 40, left: 20,
                    child: ZenButton(
                      padding: const EdgeInsets.all(12), borderRadius: 20,
                      backgroundColor: Colors.black.withOpacity(0.5),
                      onPressed: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 📄 Tab
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: theme.colorScheme.primary.withOpacity(0.05))),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: theme.primaryColor,
              labelColor: theme.primaryColor,
              unselectedLabelColor: theme.colorScheme.secondary,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: '选集'),
                Tab(text: '换源'),
              ],
            ),
          ),

          // 📄 TabView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEpisodeTab(theme),
                _buildSourceTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeTab(ThemeData theme) {
    if (_isSearching) return const Center(child: CircularProgressIndicator());
    if (_currentSource == null) return const Center(child: Text('暂无资源'));
    
    final group = _currentSource!.playGroups.first;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_currentSource!.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('来源: ${_currentSource!.sourceName} • ${group.name}', style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final isCurrent = _currentEpisodeIndex == index && _isPlaying;
                return GestureDetector(
                  onTap: () => _initializePlayer(group.urls[index], index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isCurrent ? theme.primaryColor : theme.colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(group.titles[index], maxLines: 1, style: TextStyle(color: isCurrent ? theme.colorScheme.onPrimary : theme.colorScheme.primary, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, fontSize: 11)),
                  ),
                );
              },
              childCount: group.urls.length,
            ),
          ),
        ),

        if (_fullSubject?.description != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  Text('剧情简介', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 12),
                  Text(_fullSubject!.description!, style: TextStyle(color: theme.colorScheme.primary.withOpacity(0.7), fontSize: 13, height: 1.6)),
                ],
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildSourceTab(ThemeData theme) {
    if (_isSearching) return const Center(child: CircularProgressIndicator());
    if (_availableSources.isEmpty) return const Center(child: Text('未搜到匹配资源'));

    // 按评分排序（如果有评分数据）
    final sortedSources = List<VideoDetail>.from(_availableSources);
    if (_scoreMap.isNotEmpty) {
      sortedSources.sort((a, b) {
        final aKey = '${a.source}-${a.id}';
        final bKey = '${b.source}-${b.id}';
        final aScore = _scoreMap[aKey] ?? 0.0;
        final bScore = _scoreMap[bKey] ?? 0.0;
        return bScore.compareTo(aScore);
      });
    }

    return Column(
      children: [
        // 优选状态提示
        if (_isOptimizing)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Text('正在检测播放源质量...', style: TextStyle(color: theme.primaryColor, fontSize: 12)),
              ],
            ),
          ),

        // 播放源列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: sortedSources.length,
            itemBuilder: (context, index) {
              final res = sortedSources[index];
              final isSelected = _currentSource == res;
              final sourceKey = '${res.source}-${res.id}';
              final qualityInfo = _qualityInfoMap[sourceKey];
              final score = _scoreMap[sourceKey];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => _switchSource(res),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.primaryColor.withOpacity(0.1)
                          : theme.colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? Border.all(color: theme.primaryColor.withOpacity(0.3), width: 2)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题行
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                res.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? theme.primaryColor : theme.colorScheme.primary,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 分辨率标签
                            if (qualityInfo != null && !qualityInfo.hasError)
                              _buildQualityBadge(qualityInfo.quality, theme),
                            if (isSelected)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Icon(Icons.check_circle, color: theme.primaryColor, size: 20),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 源信息行
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                res.sourceName,
                                style: TextStyle(fontSize: 10, color: theme.colorScheme.secondary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${res.playGroups.first.urls.length} 集',
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary),
                            ),
                            if (score != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '评分: ${score.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // 质量信息行
                        if (qualityInfo != null && !qualityInfo.hasError) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildInfoChip(
                                icon: Icons.speed,
                                label: qualityInfo.loadSpeed,
                                color: Colors.green,
                                theme: theme,
                              ),
                              const SizedBox(width: 12),
                              _buildInfoChip(
                                icon: Icons.network_ping,
                                label: '${qualityInfo.pingTime}ms',
                                color: Colors.orange,
                                theme: theme,
                              ),
                            ],
                          ),
                        ],

                        // 检测失败提示
                        if (qualityInfo != null && qualityInfo.hasError) ...[
                          const SizedBox(height: 8),
                          Text(
                            '质量检测失败',
                            style: TextStyle(fontSize: 11, color: Colors.red.withOpacity(0.7)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建分辨率标签
  Widget _buildQualityBadge(String quality, ThemeData theme) {
    Color color;
    switch (quality) {
      case '4K':
      case '2K':
        color = Colors.purple;
        break;
      case '1080p':
      case '720p':
        color = Colors.green;
        break;
      case '480p':
      case 'SD':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        quality,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 构建信息芯片
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}