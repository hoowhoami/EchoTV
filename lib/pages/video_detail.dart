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

  // 分页相关
  int _currentPage = 0;
  final int _episodesPerPage = 50;
  bool _descending = false;

  // PC端选集面板折叠状态（仅在 lg 及以上屏幕有效）
  bool _isEpisodeSelectorCollapsed = false;

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isPC = screenWidth > 800;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildMainLayout(theme, isPC, screenWidth),
    );
  }

  Widget _buildMainLayout(ThemeData theme, bool isPC, double screenWidth) {
    return CustomScrollView(
      slivers: [
        // 透明 AppBar（返回按钮）
        SliverAppBar(
          backgroundColor: Colors.transparent,
          floating: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ZenButton(
              onPressed: () => Navigator.pop(context),
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              borderRadius: 20,
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
            ),
          ),
        ),

        // 内容区域
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isPC ? 48 : 16,
              vertical: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 播放器和选集区域
                _buildPlayerAndEpisodeSection(theme, isPC, screenWidth),
                const SizedBox(height: 24),

                // 详情区域
                _buildDetailSection(theme, isPC),

                // 底部留白
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 播放器和选集区域（参考 LunaTV 的 Grid 布局）
  Widget _buildPlayerAndEpisodeSection(ThemeData theme, bool isPC, double screenWidth) {
    if (!isPC) {
      // 移动端：垂直布局
      return Column(
        children: [
          _buildVideoPlayer(theme, isPC),
          const SizedBox(height: 16),
          SizedBox(
            height: 360,
            child: _buildEpisodePanel(theme),
          ),
        ],
      );
    }

    // PC端：使用 Row 模拟 Grid 效果（3:1 比例）
    return Column(
      children: [
        // 折叠控制按钮（仅PC端显示）
        Align(
          alignment: Alignment.centerRight,
          child: _buildCollapseButton(theme),
        ),
        const SizedBox(height: 8),

        // 播放器 + 选集面板
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 播放器区域（占 3/4）
            Expanded(
              flex: 3,
              child: _buildVideoPlayer(theme, isPC),
            ),
            const SizedBox(width: 16),

            // 选集面板（占 1/4）
            if (!_isEpisodeSelectorCollapsed)
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: _calculatePlayerHeight(screenWidth),
                  child: _buildEpisodePanel(theme),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 折叠按钮（仅PC端）- 简化风格
  Widget _buildCollapseButton(ThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _isEpisodeSelectorCollapsed = !_isEpisodeSelectorCollapsed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isEpisodeSelectorCollapsed ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              size: 12,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 6),
            Text(
              _isEpisodeSelectorCollapsed ? '显示' : '隐藏',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 计算播放器高度（参考 LunaTV）
  double _calculatePlayerHeight(double screenWidth) {
    if (screenWidth < 1200) return 500;
    if (screenWidth < 1600) return 650;
    return 750;
  }

  /// 选集面板（包含 Tab）- 简洁风格
  Widget _buildEpisodePanel(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          _buildTabBar(theme),
          Expanded(child: _buildTabView(theme)),
        ],
      ),
    );
  }

  /// 详情区域（参考 LunaTV：封面在左侧）
  Widget _buildDetailSection(ThemeData theme, bool isPC) {
    if (isPC) {
      // PC端：左右布局，封面在左侧
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面（在左侧）
          SizedBox(
            width: 180,
            child: _buildPoster(theme),
          ),
          const SizedBox(width: 24),

          // 文字信息（占剩余空间）
          Expanded(
            child: _buildVideoInfo(theme),
          ),
        ],
      );
    }

    // 移动端：只显示文字信息
    return _buildVideoInfo(theme);
  }

  /// 封面 - iOS 风格
  Widget _buildPoster(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Image.network(
          widget.subject.cover,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.movie,
                size: 48,
                color: theme.colorScheme.secondary,
              ),
            );
          },
        ),
      ),
    );
  }

  /// 视频信息文字 - 简洁风格
  Widget _buildVideoInfo(ThemeData theme) {
    final group = _currentSource?.playGroups.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题和收藏按钮
        Row(
          children: [
            Expanded(
              child: Text(
                widget.subject.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () {
                // TODO: 收藏功能
              },
              icon: Icon(
                Icons.favorite_border,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 关键信息行
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (widget.subject.year != null)
              Text(
                widget.subject.year!,
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontSize: 13,
                ),
              ),
            if (group != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _currentSource?.sourceName ?? '',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (group != null)
              Text(
                '${group.urls.length} 集',
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontSize: 13,
                ),
              ),
            if (widget.subject.rate.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⭐ ', style: TextStyle(fontSize: 12)),
                  Text(
                    widget.subject.rate,
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),

        // 剧情简介
        if (_fullSubject?.description != null)
          Text(
            _fullSubject!.description!,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.6,
            ),
          ),
      ],
    );
  }

  Widget _buildVideoPlayer(ThemeData theme, [bool isPC = false]) {
    // PC端使用固定高度，移动端使用 16:9 比例
    if (isPC) {
      final screenWidth = MediaQuery.of(context).size.width;
      final playerHeight = _calculatePlayerHeight(screenWidth);

      return SizedBox(
        height: playerHeight,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
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
                      Container(color: Colors.black.withValues(alpha: 0.5)),
                      Center(
                        child: _isSearching
                          ? const CircularProgressIndicator(color: Colors.white)
                          : _currentSource != null
                            ? GestureDetector(
                                onTap: () => _initializePlayer(_currentSource!.playGroups.first.urls[0], 0),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, size: 48, color: Colors.black),
                                ),
                              )
                            : Text('未找到资源', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // 移动端：16:9 比例
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
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
                    Container(color: Colors.black.withValues(alpha: 0.5)),
                    Center(
                      child: _isSearching
                        ? const CircularProgressIndicator(color: Colors.white)
                        : _currentSource != null
                          ? GestureDetector(
                              onTap: () => _initializePlayer(_currentSource!.playGroups.first.urls[0], 0),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.play_arrow_rounded, size: 40, color: Colors.black),
                              ),
                            )
                          : Text('未找到资源', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: theme.primaryColor,
        labelColor: theme.primaryColor,
        unselectedLabelColor: theme.colorScheme.secondary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        indicatorWeight: 2,
        tabs: const [
          Tab(text: '选集'),
          Tab(text: '换源'),
        ],
      ),
    );
  }

  Widget _buildTabView(ThemeData theme) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildEpisodeTab(theme),
        _buildSourceTab(theme),
      ],
    );
  }

  Widget _buildEpisodeTab(ThemeData theme) {
    if (_isSearching) return const Center(child: CircularProgressIndicator());
    if (_currentSource == null) return const Center(child: Text('暂无资源'));

    final group = _currentSource!.playGroups.first;
    final totalEpisodes = group.urls.length;
    final pageCount = (totalEpisodes / _episodesPerPage).ceil();

    // 计算当前页的集数范围
    final startIndex = _currentPage * _episodesPerPage;
    final endIndex = (startIndex + _episodesPerPage).clamp(0, totalEpisodes);

    // 响应式布局
    final screenWidth = MediaQuery.of(context).size.width;
    final isPC = screenWidth > 800;
    final crossAxisCount = isPC ? 4 : 3;

    return CustomScrollView(
      slivers: [
        // 分页选择器
        if (pageCount > 1)
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isPC ? 12 : 16,
                vertical: isPC ? 10 : 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: pageCount,
                        itemBuilder: (context, index) {
                        final start = index * _episodesPerPage + 1;
                        final end = ((index + 1) * _episodesPerPage).clamp(0, totalEpisodes);
                        final isActive = index == _currentPage;
                        return GestureDetector(
                          onTap: () => setState(() => _currentPage = index),
                          child: Container(
                            margin: EdgeInsets.only(right: isPC ? 8 : 4),
                            padding: EdgeInsets.symmetric(
                              horizontal: isPC ? 18 : 8,
                              vertical: isPC ? 10 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive ? theme.primaryColor : theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(isPC ? 8 : 4),
                            ),
                            child: Center(
                              child: Text(
                                '$start-$end',
                                style: TextStyle(
                                  color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onPrimaryContainer,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  fontSize: isPC ? 12 : 10,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.swap_vert, color: theme.primaryColor, size: isPC ? 26 : 18),
                    onPressed: () => setState(() => _descending = !_descending),
                  ),
                ],
              ),
            ),
          ),

        // 集数网格
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: isPC ? 12 : 16,
            vertical: isPC ? 10 : 4,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: isPC ? 10 : 4,
              crossAxisSpacing: isPC ? 10 : 4,
              childAspectRatio: isPC ? 1.8 : 2.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final index = _descending ? (endIndex - 1 - i) : (startIndex + i);
                final isCurrent = _currentEpisodeIndex == index && _isPlaying;
                return GestureDetector(
                  onTap: () => _initializePlayer(group.urls[index], index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isCurrent ? theme.primaryColor : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(isPC ? 8 : 4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      group.titles[index],
                      maxLines: 1,
                      style: TextStyle(
                        color: isCurrent ? theme.colorScheme.onPrimary : theme.colorScheme.onPrimaryContainer,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        fontSize: isPC ? 12 : 11,
                      ),
                    ),
                  ),
                );
              },
              childCount: endIndex - startIndex,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text('正在检测播放源质量...', style: TextStyle(color: theme.primaryColor, fontSize: 11)),
              ],
            ),
          ),

        // 播放源列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: sortedSources.length,
            itemBuilder: (context, index) {
              final res = sortedSources[index];
              final isSelected = _currentSource == res;
              final sourceKey = '${res.source}-${res.id}';
              final qualityInfo = _qualityInfoMap[sourceKey];
              final score = _scoreMap[sourceKey];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _switchSource(res),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.primaryColor.withValues(alpha: 0.1)
                          : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: theme.primaryColor.withValues(alpha: 0.3), width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        // 左侧：标题和标签
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 标题行
                              Wrap(
                                spacing: 6,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    res.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? theme.primaryColor : theme.colorScheme.primary,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // 分辨率标签
                                  if (qualityInfo != null && !qualityInfo.hasError)
                                    _buildQualityBadge(qualityInfo.quality, theme),
                                  // 选中图标
                                  if (isSelected)
                                    Icon(Icons.check_circle, color: theme.primaryColor, size: 14),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // 源信息行
                              Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                children: [
                                  Text(
                                    res.sourceName,
                                    style: TextStyle(fontSize: 10, color: theme.colorScheme.secondary),
                                  ),
                                  Text(
                                    '${res.playGroups.first.urls.length} 集',
                                    style: TextStyle(fontSize: 10, color: theme.colorScheme.secondary),
                                  ),
                                  if (score != null)
                                    Text(
                                      '⭐ ${score.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 右侧：质量信息（如果有）
                        if (qualityInfo != null && !qualityInfo.hasError)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.speed, size: 10, color: Colors.green),
                                  const SizedBox(width: 3),
                                  Text(
                                    qualityInfo.loadSpeed,
                                    style: TextStyle(fontSize: 9, color: Colors.green),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.network_ping, size: 10, color: Colors.orange),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${qualityInfo.pingTime}ms',
                                    style: TextStyle(fontSize: 9, color: Colors.orange),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
        color: color.withValues(alpha: 0.15),
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
}