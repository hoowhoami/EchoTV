import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/movie.dart';
import '../models/site.dart';
import '../services/cms_service.dart';
import '../services/douban_service.dart';
import '../services/config_service.dart';
import '../services/video_quality_service.dart';
import '../services/source_optimizer_service.dart';
import '../widgets/zen_ui.dart';
import '../widgets/cover_image.dart';

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

  final Map<String, VideoQualityInfo> _qualityInfoMap = {};
  final Map<String, double> _scoreMap = {};
  final Set<String> _testedSources = {};

  bool _descending = false;
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
    bool hasSetFirstSource = false;

    await for (final results in cmsService.searchAllStream(sites, widget.subject.title)) {
      if (!mounted) break;

      final matchedResults = results.where((res) {
        final sTitle = res.title.replaceAll(' ', '').toLowerCase();
        final tTitle = widget.subject.title.replaceAll(' ', '').toLowerCase();
        return sTitle.contains(tTitle) || tTitle.contains(sTitle);
      }).toList();

      final seenKeys = <String>{};
      final filtered = <VideoDetail>[];
      for (var res in matchedResults) {
        final sourceKey = '${res.source}-${res.id}';
        if (!seenKeys.contains(sourceKey)) {
          seenKeys.add(sourceKey);
          filtered.add(res);
        }
      }

      filtered.sort((a, b) {
        final aExact = a.title.replaceAll(' ', '').toLowerCase() == widget.subject.title.replaceAll(' ', '').toLowerCase();
        final bExact = b.title.replaceAll(' ', '').toLowerCase() == widget.subject.title.replaceAll(' ', '').toLowerCase();
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
        return b.playGroups.first.urls.length.compareTo(a.playGroups.first.urls.length);
      });

      setState(() {
        _availableSources = filtered;
        if (!hasSetFirstSource && filtered.isNotEmpty) {
          _currentSource = filtered.first;
          _isSearching = false;
          hasSetFirstSource = true;
        }
      });

      if (hasSetFirstSource && filtered.length > 1 && !_isOptimizing) {
        _optimizeBestSource(filtered);
      }
    }

    if (mounted) setState(() => _isSearching = false);
  }

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
          if (!_isPlaying) _currentSource = result.bestSource;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isOptimizing = false);
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
      if (resumePosition != null && resumePosition > 1) {
        await _videoController!.seekTo(Duration(seconds: resumePosition.toInt()));
      }
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).primaryColor,
          handleColor: Theme.of(context).primaryColor,
        ),
      );
    } catch (e) {}
    if (mounted) setState(() {});
  }

  Future<void> _switchSource(VideoDetail newSource) async {
    final oldEpisodeIndex = _currentEpisodeIndex;
    final oldPlayPosition = _videoController?.value.position.inSeconds.toDouble() ?? 0.0;
    setState(() => _currentSource = newSource);
    final newGroup = newSource.playGroups.first;
    int targetIndex = oldEpisodeIndex >= newGroup.urls.length ? 0 : oldEpisodeIndex;
    if (_isPlaying) {
      final resumePosition = (targetIndex == oldEpisodeIndex && oldPlayPosition > 1) ? oldPlayPosition : null;
      await _initializePlayer(newGroup.urls[targetIndex], targetIndex, resumePosition: resumePosition);
    } else {
      setState(() => _currentEpisodeIndex = targetIndex);
    }
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
    final horizontalPadding = isPC ? 48.0 : 24.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 背景氛围：高斯模糊海报
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: CoverImage(imageUrl: widget.subject.cover),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),

          CustomScrollView(
            slivers: [
              // 沉浸式返回头
              SliverAppBar(
                backgroundColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                        child: IconButton(
                          icon: const Icon(LucideIcons.chevronLeft, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPlayerAndEpisodeSection(theme, isPC, screenWidth),
                      const SizedBox(height: 48),
                      _buildDetailSection(theme, isPC),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerAndEpisodeSection(ThemeData theme, bool isPC, double screenWidth) {
    if (!isPC) {
      return Column(
        children: [
          _buildVideoPlayer(theme, false),
          const SizedBox(height: 24),
          _buildEpisodePanel(theme, 360),
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildVideoPlayer(theme, true),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isEpisodeSelectorCollapsed ? 0 : 320,
              margin: EdgeInsets.only(left: _isEpisodeSelectorCollapsed ? 0 : 24),
              child: _isEpisodeSelectorCollapsed 
                  ? const SizedBox() 
                  : _buildEpisodePanel(theme, _calculatePlayerHeight(screenWidth)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => setState(() => _isEpisodeSelectorCollapsed = !_isEpisodeSelectorCollapsed),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_isEpisodeSelectorCollapsed ? LucideIcons.maximize2 : LucideIcons.minimize2, size: 14, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(_isEpisodeSelectorCollapsed ? '展开选集' : '收起选集', style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _calculatePlayerHeight(double screenWidth) {
    if (screenWidth < 1200) return 400;
    if (screenWidth < 1600) return 520;
    return 640;
  }

  Widget _buildVideoPlayer(ThemeData theme, bool isPC) {
    final content = Stack(
      children: [
        if (_isPlaying)
          Center(
            child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(),
          )
        else
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(child: CoverImage(imageUrl: widget.subject.cover)),
                Container(color: Colors.black.withValues(alpha: 0.6)),
                Center(
                  child: _isSearching
                    ? const CircularProgressIndicator(color: Colors.white)
                    : _currentSource != null
                      ? ZenButton(
                          onPressed: () => _initializePlayer(_currentSource!.playGroups.first.urls[0], 0),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.play, size: 18),
                              SizedBox(width: 8),
                              Text('立即播放'),
                            ],
                          ),
                        )
                      : const Text('未找到资源', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
      ],
    );

    final playerContainer = Container(
      height: isPC ? _calculatePlayerHeight(MediaQuery.of(context).size.width) : null,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 20)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (!isPC) {
      return AspectRatio(aspectRatio: 16 / 9, child: playerContainer);
    }
    return playerContainer;
  }

  Widget _buildEpisodePanel(ThemeData theme, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorColor: theme.colorScheme.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: const [Tab(text: '选集'), Tab(text: '源站')],
          ),
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

  Widget _buildDetailSection(ThemeData theme, bool isPC) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isPC) ...[
          SizedBox(
            width: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(aspectRatio: 2/3, child: CoverImage(imageUrl: widget.subject.cover)),
            ),
          ),
          const SizedBox(width: 48),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.subject.title,
                      style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900, fontSize: isPC ? 32 : 24),
                    ),
                  ),
                  if (widget.subject.rate.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('⭐ ${widget.subject.rate}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  if (widget.subject.year != null) _buildInfoBadge(widget.subject.year!, theme),
                  if (_currentSource != null) _buildInfoBadge(_currentSource!.sourceName, theme, isAccent: true),
                  _buildInfoBadge('${_currentSource?.playGroups.first.urls.length ?? 0} 集', theme),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _fullSubject?.description ?? '正在加载详情...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.8,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBadge(String text, ThemeData theme, {bool isAccent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAccent ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isAccent ? theme.colorScheme.primary : theme.colorScheme.secondary,
        ),
      ),
    );
  }

  Widget _buildEpisodeTab(ThemeData theme) {
    if (_isSearching) return const Center(child: CircularProgressIndicator());
    if (_currentSource == null) return const Center(child: Text('暂无资源'));
    final group = _currentSource!.playGroups.first;
    final isPC = MediaQuery.of(context).size.width > 800;
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isPC ? 4 : 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: group.urls.length,
      itemBuilder: (context, i) {
        final index = _descending ? (group.urls.length - 1 - i) : i;
        final isCurrent = _currentEpisodeIndex == index && _isPlaying;
        return GestureDetector(
          onTap: () => _initializePlayer(group.urls[index], index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              group.titles[index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCurrent ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white) : theme.colorScheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceTab(ThemeData theme) {
    if (_availableSources.isEmpty) return const Center(child: Text('未搜到资源'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _availableSources.length,
      itemBuilder: (context, index) {
        final res = _availableSources[index];
        final isSelected = _currentSource == res;
        final quality = _qualityInfoMap['${res.source}-${res.id}'];
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => _switchSource(res),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.3) : theme.dividerColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(res.sourceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('${res.playGroups.first.urls.length} 个资源', style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary)),
                            if (quality != null && !quality.hasError) ...[
                              const SizedBox(width: 12),
                              Icon(LucideIcons.gauge, size: 10, color: Colors.green.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Text(quality.loadSpeed, style: const TextStyle(fontSize: 10, color: Colors.green)),
                              const SizedBox(width: 8),
                              Icon(LucideIcons.activity, size: 10, color: Colors.orange.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Text('${quality.pingTime}ms', style: const TextStyle(fontSize: 10, color: Colors.orange)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (quality != null && !quality.hasError)
                    _buildQualityBadge(quality.quality),
                  if (isSelected) Icon(LucideIcons.checkCircle2, size: 18, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQualityBadge(String quality) {
    Color color = Colors.green;
    if (quality.contains('4K')) color = Colors.purple;
    if (quality.contains('SD')) color = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(quality, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
