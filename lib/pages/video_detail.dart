import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/movie.dart';
import '../models/site.dart';
import '../services/cms_service.dart';
import '../services/douban_service.dart';
import '../services/config_service.dart';
import '../providers/history_provider.dart';
import '../services/video_quality_service.dart';
import '../services/source_optimizer_service.dart';
import '../widgets/cover_image.dart';
import '../widgets/zen_ui.dart';
import '../widgets/video_player.dart';

class VideoDetailPage extends ConsumerStatefulWidget {
  final DoubanSubject subject;

  const VideoDetailPage({super.key, required this.subject});

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

enum LoadingStage { searching, preferring, fetching, ready }

class _VideoDetailPageState extends ConsumerState<VideoDetailPage> with WidgetsBindingObserver, TickerProviderStateMixin {
  late TabController _tabController;
  late HistoryNotifier _historyNotifier;
  
  DoubanSubject? _fullSubject;
  bool _isDetailLoading = true;
  String _doubanId = '';
  
  // 核心数据
  List<VideoDetail> _availableSources = [];
  VideoDetail? _currentSource;
  int _currentEpisodeIndex = 0;
  double? _initialResumePosition;
  bool _autoPlayNext = true;
  SkipConfig _skipConfig = SkipConfig();

  // 状态跟踪
  LoadingStage _loadingStage = LoadingStage.searching;
  String _loadingMessage = '';
  bool _isSearching = true;
  bool _isPlaying = false;
  bool _noSitesConfigured = false;
  bool _isOptimizing = false;
  bool _hasTriggeredInitialInit = false;
  bool _descending = false;
  bool _isEpisodeSelectorCollapsed = false;

  Map<String, double> _scoreMap = {};
  Map<String, VideoQualityInfo> _qualityInfoMap = {};
  final Set<String> _testedSources = {};
  
  final GlobalKey<EchoVideoPlayerState> _playerKey = GlobalKey<EchoVideoPlayerState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _doubanId = widget.subject.id;
    _checkHistoryAndLoadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _historyNotifier = ref.read(historyProvider.notifier);
  }

  void _checkHistoryAndLoadData() async {
    // 1. 尝试从历史记录中恢复状态
    final history = ref.read(historyProvider).value ?? [];
    final record = history.firstWhere(
      (r) => r.searchTitle == widget.subject.title,
      orElse: () => PlayRecord(
        title: '', 
        sourceName: '', 
        cover: '', 
        year: '', 
        index: 0, 
        totalEpisodes: 0, 
        playTime: 0, 
        totalTime: 0, 
        saveTime: 0, 
        searchTitle: ''
      ),
    );

    if (record.title.isNotEmpty) {
      debugPrint('找到历史记录：第 ${record.index} 集，进度 ${record.playTime}s');
      setState(() {
        _currentEpisodeIndex = record.index;
        _initialResumePosition = record.playTime.toDouble();
        if (_doubanId.isEmpty && record.doubanId != null && record.doubanId!.isNotEmpty) {
          _doubanId = record.doubanId!;
        }
      });
    }

    // 2. 正常加载数据
    _loadData();
  }

  void _loadData() async {
    final doubanService = ref.read(doubanServiceProvider);
    final cmsService = ref.read(cmsServiceProvider);
    final configService = ref.read(configServiceProvider);

    setState(() {
      _loadingStage = LoadingStage.searching;
      _loadingMessage = '🔍 正在搜索播放源...';
    });

    // 如果没有豆瓣 ID，尝试根据标题搜索一个
    if (_doubanId.isEmpty) {
      try {
        final searchResults = await doubanService.search(widget.subject.title);
        if (searchResults.isNotEmpty) {
          final targetTitle = widget.subject.title.replaceAll(' ', '').toLowerCase();
          final bestMatch = searchResults.firstWhere(
            (s) => s.title.replaceAll(' ', '').toLowerCase() == targetTitle,
            orElse: () => searchResults.first,
          );
          _doubanId = bestMatch.id;
          debugPrint('🎬 通过搜索找到豆瓣 ID: $_doubanId');
        }
      } catch (e) {
        debugPrint('❌ 搜索豆瓣 ID 失败: $e');
      }
    }

    if (_doubanId.isNotEmpty) {
      doubanService.getDetail(_doubanId).then((val) {
        if (val == null) {
          debugPrint('⚠️ 豆瓣详情获取为空: id=$_doubanId');
        } else {
          debugPrint('✅ 豆瓣详情获取成功: ${val.title}');
        }
        if (mounted) {
          setState(() {
            _fullSubject = val;
            _isDetailLoading = false;
          });
        }
      }).catchError((e) {
        debugPrint('❌ 豆瓣详情获取失败: $e');
        if (mounted) setState(() => _isDetailLoading = false);
      });
    } else {
      setState(() => _isDetailLoading = false);
    }

    final sites = await configService.getSites();
    final activeSites = sites.where((s) => !s.disabled).toList();

    if (activeSites.isEmpty) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _noSitesConfigured = true;
          _loadingMessage = '❌ 未配置有效视频源';
        });
      }
      return;
    }

    setState(() {
      _noSitesConfigured = false;
    });

    final Set<String> processedKeys = {};
    
    await for (final results in cmsService.searchAllStream(activeSites, widget.subject.title)) {
      if (!mounted) break;

      final List<VideoDetail> newlyFound = [];
      
      for (var res in results) {
        final sTitle = res.title.replaceAll(' ', '').toLowerCase();
        final tTitle = widget.subject.title.replaceAll(' ', '').toLowerCase();
        if (sTitle.contains(tTitle) || tTitle.contains(sTitle)) {
          final key = '${res.source}-${res.id}';
          if (!processedKeys.contains(key)) {
            processedKeys.add(key);
            newlyFound.add(res);
          }
        }
      }

      if (mounted && newlyFound.isNotEmpty) {
        setState(() {
          _availableSources.addAll(newlyFound);
          _noSitesConfigured = false;
        });

        if (!_hasTriggeredInitialInit) {
          _hasTriggeredInitialInit = true;
          _startDynamicInitialization();
        }

        if (!_isOptimizing) {
          _optimizeBestSource(newlyFound);
        }
      }
    }

    if (mounted) setState(() => _isSearching = false);
  }

  /// 动态轮询初始化：等待最佳时机启动播放器
  Future<void> _startDynamicInitialization() async {
    int tick = 0;
    const int maxTicks = 20; // 约 4 秒

    while (tick < maxTicks) {
      if (!mounted || _isPlaying) return;

      final bool hasHighQualitySource = _scoreMap.values.any((score) => score >= 90);
      final bool hasEnoughSamples = _testedSources.length >= 3 || _testedSources.length == _availableSources.length;
      final bool isSearchDone = !_isSearching;

      if (hasHighQualitySource || (isSearchDone && hasEnoughSamples) || tick >= 15) {
        break;
      }

      await Future.delayed(const Duration(milliseconds: 200));
      tick++;
    }

    if (mounted && _availableSources.isNotEmpty && !_isPlaying) {
      setState(() {
        _loadingStage = LoadingStage.preferring;
        _loadingMessage = '⚡ 正在优选最佳线路...';
      });

      final optimizer = ref.read(sourceOptimizerServiceProvider);
      final result = await optimizer.selectBestSource(_availableSources, cachedQualityInfo: _qualityInfoMap);
      
      if (mounted) {
        VideoDetail best = result.bestSource;
        setState(() {
          _currentSource = best;
          _qualityInfoMap.addAll(result.qualityInfoMap);
          _scoreMap.addAll(result.scoreMap);
          _loadingStage = LoadingStage.fetching;
          _loadingMessage = '🎬 正在准备播放...';
        });

        // 异步抓取更完整的详情（如完整播放列表），不阻塞 UI 但确保播放前数据最新
        await _fetchFullDetail(best);
        
        _loadSkipConfig();
        _handlePlayAction(_currentEpisodeIndex, resumePosition: _initialResumePosition);
      }
    }
  }

  Future<void> _optimizeBestSource(List<VideoDetail> sources) async {
    if (sources.isEmpty || _isOptimizing) return;
    setState(() => _isOptimizing = true);
    
    final qualityService = ref.read(videoQualityServiceProvider);
    final List<VideoDetail> queue = List.from(sources);
    int currentIndex = 0;
    const int maxConcurrent = 3;

    Future<void> worker() async {
      while (currentIndex < queue.length) {
        final source = queue[currentIndex++];
        final key = '${source.source}-${source.id}';
        if (_qualityInfoMap.containsKey(key) && !_qualityInfoMap[key]!.hasError) continue;
        
        try {
          final url = source.playGroups.first.urls.length > 1 ? source.playGroups.first.urls[1] : source.playGroups.first.urls[0];
          final quality = await qualityService.detectQuality(url);
                      if (mounted) {
                        setState(() {
                          _qualityInfoMap[key] = quality;
                          _testedSources.add(key);
                        });
                        // 移除 _applyIncrementalOptimization()，不再自动纠偏
                      }        } catch (e) {}
      }
    }

    await Future.wait(List.generate(queue.length < maxConcurrent ? queue.length : maxConcurrent, (_) => worker()));
    if (mounted) setState(() => _isOptimizing = false);
  }

  void _applyIncrementalOptimization() async {
    // 仅更新测速数据，不再自动更新 _currentSource
    if (!mounted) return;
    final optimizer = ref.read(sourceOptimizerServiceProvider);
    final result = await optimizer.selectBestSource(_availableSources, cachedQualityInfo: _qualityInfoMap);
    
    if (mounted) {
      setState(() {
        _qualityInfoMap.addAll(result.qualityInfoMap);
        _scoreMap.addAll(result.scoreMap);
      });
    }
  }

  void _handlePlayAction(int index, {double? resumePosition}) {
    if (_currentSource == null) return;
    setState(() {
      // 如果外部传入了 resumePosition 则使用，否则尝试沿用之前的（用于自动恢复）
      _initialResumePosition = resumePosition ?? _initialResumePosition;
      _currentEpisodeIndex = index;
    });
  }

  Future<void> _switchSource(VideoDetail newSource) async {
    setState(() {
      _currentSource = newSource;
    });
    
    // 异步尝试获取更完整的详情（如播放列表），不阻塞主线程切换
    _fetchFullDetail(newSource);

    _loadSkipConfig();
    final targetIndex = _currentEpisodeIndex >= newSource.playGroups.first.urls.length ? 0 : _currentEpisodeIndex;
    _handlePlayAction(targetIndex);
  }

  void _loadSkipConfig() async {
    if (_currentSource == null) return;
    final key = '${_currentSource!.source}-${_currentSource!.id}';
    final config = await ref.read(configServiceProvider).getSkipConfigs();
    if (mounted && config.containsKey(key)) {
      setState(() {
        _skipConfig = config[key]!;
      });
    }
  }

  Future<void> _fetchFullDetail(VideoDetail partial) async {
    try {
      final cmsService = ref.read(cmsServiceProvider);
      final configService = ref.read(configServiceProvider);
      final activeSites = await configService.getSites();
      final site = activeSites.firstWhere((s) => s.key == partial.source);
      
      final fullDetail = await cmsService.getDetail(site, partial.id);
      if (fullDetail != null && mounted && _currentSource?.id == partial.id) {
        setState(() {
          _currentSource = fullDetail;
          // 同步更新缓存列表
          final idx = _availableSources.indexWhere((s) => s.id == partial.id && s.source == partial.source);
          if (idx != -1) _availableSources[idx] = fullDetail;
        });
      }
    } catch (_) {}
  }

  void _playNextEpisode() {
    if (_currentSource == null) return;
    final nextIndex = _currentEpisodeIndex + 1;
    if (nextIndex < _currentSource!.playGroups.first.urls.length) {
      _handlePlayAction(nextIndex);
    }
  }

  Future<void> _savePlayRecord(Duration position, Duration duration, {bool isFinal = false}) async {
    if (_currentSource == null || !mounted) return;
    
    // 只有在进度有实际变化（大于0）或者为了保存最后进度时才记录
    if (position.inSeconds == 0 && duration.inSeconds == 0) return;

    // 如果不是强制保存（isFinal），则每 10 秒保存一次
    if (!isFinal && position.inSeconds % 10 != 0) return;

    final record = PlayRecord(
      title: widget.subject.title,
      sourceName: _currentSource!.sourceName,
      cover: widget.subject.cover,
      year: widget.subject.year ?? '',
      index: _currentEpisodeIndex,
      totalEpisodes: _currentSource!.playGroups.first.urls.length,
      playTime: position.inSeconds,
      totalTime: duration.inSeconds > 0 ? duration.inSeconds : (_initialResumePosition?.toInt() ?? 0),
      saveTime: DateTime.now().millisecondsSinceEpoch,
      searchTitle: widget.subject.title,
      doubanId: _doubanId,
    );
    try {
      Future.microtask(() {
        _historyNotifier.saveRecord(record);
      });
    } catch (e) {
      debugPrint('保存历史记录失败: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // 这里的进度保存由 EchoVideoPlayer 的 onProgress 持续进行
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPC = screenWidth > 960;
    final horizontalPadding = isPC ? 48.0 : 24.0;

    return ZenScaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Opacity(opacity: 0.1, child: CoverImage(imageUrl: widget.subject.cover))),
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container(color: Colors.transparent))),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                floating: true,
                pinned: false,
                leading: IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  widget.subject.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 24),
                      _buildDetailSection(theme, isPC),
                      const SizedBox(height: 80),
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
      return Column(children: [_buildVideoPlayer(theme, false), const SizedBox(height: 20), _buildEpisodePanel(theme, 360)]);
    }
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _buildVideoPlayer(theme, true)),
            const SizedBox(width: 24),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _isEpisodeSelectorCollapsed ? 0 : (screenWidth > 1400 ? 400 : 360),
              child: _isEpisodeSelectorCollapsed ? const SizedBox() : _buildEpisodePanel(theme, _calculatePlayerHeight(screenWidth)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => setState(() => _isEpisodeSelectorCollapsed = !_isEpisodeSelectorCollapsed),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: theme.dividerColor)),
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
    Widget content;
    
    if (_currentSource == null) {
      content = Stack(
        children: [
          Positioned.fill(child: CoverImage(imageUrl: widget.subject.cover)),
          Container(color: Colors.black.withValues(alpha: 0.6)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSearching) ...[
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                ],
                Text(
                  _loadingMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      final url = _currentSource!.playGroups.first.urls[_currentEpisodeIndex];
      content = EchoVideoPlayer(
        key: _playerKey,
        url: url,
        title: '${widget.subject.title} - ${_currentSource!.playGroups.first.titles[_currentEpisodeIndex]}',
        referer: '', // 移除自动生成的 Origin Referer，避免触发防盗链
        initialPosition: _initialResumePosition,
        skipConfig: _skipConfig,
        onSkipConfigChange: (newConfig) async {
          final key = '${_currentSource!.source}-${_currentSource!.id}';
          await ref.read(configServiceProvider).saveSkipConfig(key, newConfig);
          setState(() => _skipConfig = newConfig);
        },
        hasNextEpisode: _currentEpisodeIndex < _currentSource!.playGroups.first.urls.length - 1,
        onNextEpisode: _playNextEpisode,
        onProgress: (pos, dur, {isFinal = false}) => _savePlayRecord(pos, dur, isFinal: isFinal),
        onEnded: _autoPlayNext ? _playNextEpisode : null,
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = isPC ? 48.0 : 24.0;
    final playerHeight = isPC ? _calculatePlayerHeight(screenWidth) : ((screenWidth - 2 * horizontalPadding) / (16 / 9));

    return Container(
      height: playerHeight,
      decoration: BoxDecoration(
        color: Colors.black, 
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3), 
            blurRadius: 40, 
            offset: const Offset(0, 20)
          )
        ]
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _buildEpisodePanel(ThemeData theme, double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.dividerColor)),
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
          Expanded(child: TabBarView(controller: _tabController, children: [_buildEpisodeTab(theme), _buildSourceTab(theme)])),
        ],
      ),
    );
  }

  Widget _buildDetailSection(ThemeData theme, bool isPC) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isPC) ...[
          SizedBox(width: 200, child: ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 2/3, child: CoverImage(imageUrl: widget.subject.cover)))),
          const SizedBox(width: 48),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(widget.subject.title, style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900, fontSize: isPC ? 32 : 24))),
                if ((_fullSubject?.rate ?? widget.subject.rate).isNotEmpty && (_fullSubject?.rate ?? widget.subject.rate) != '0.0') 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), 
                    child: Text('⭐ ${_fullSubject?.rate ?? widget.subject.rate}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14))
                  ),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 8, children: [
                if (widget.subject.year != null && widget.subject.year!.isNotEmpty) 
                  _buildInfoBadge(widget.subject.year!, theme),
                if (_currentSource != null) 
                  _buildInfoBadge(
                    _currentSource!.sourceName, 
                    theme, 
                    isAccent: true,
                    onTap: () => _tabController.animateTo(1)
                  ),
                if (_currentSource != null)
                  _buildInfoBadge('${_currentSource!.playGroups.first.urls.length} 集', theme)
                else if (_isSearching)
                  Container(
                    width: 60,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ]),
              const SizedBox(height: 24),
              _buildDescriptionSection(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(ThemeData theme) {
    final String? description = _fullSubject?.description ?? widget.subject.description;
    
    if (description != null && description.isNotEmpty) {
      return Text(
        description, 
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7), 
          height: 1.8, 
          fontSize: 15
        )
      );
    }

    if (!_isDetailLoading) {
       return Text(
        '暂无详情介绍',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInfoBadge(String text, ThemeData theme, {bool isAccent = false, VoidCallback? onTap}) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isAccent ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8)
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isAccent ? theme.colorScheme.primary : theme.colorScheme.secondary
            )
          )
        ),
      ),
    );
  }

  Widget _buildEpisodeTab(ThemeData theme) {
    if (_isSearching && _availableSources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: 20),
            Text('正在全网搜索播放源...', style: TextStyle(color: theme.colorScheme.secondary, fontSize: 13)),
          ],
        ),
      );
    }
    
    // 如果仍在搜索但已经有部分结果，或者搜索已结束但没结果
    if (_currentSource == null) {
      if (_isSearching) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      return Center(child: Text(_noSitesConfigured ? '未配置有效视频源' : '暂无资源'));
    }
    
    final group = _currentSource!.playGroups.first;
    
    return Stack(
      children: [
        Column(
          children: [
            // 操控栏：自动播放 & 排序
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 自动播放开关
                  GestureDetector(
                    onTap: () => setState(() => _autoPlayNext = !_autoPlayNext),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _autoPlayNext ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _autoPlayNext ? LucideIcons.playCircle : LucideIcons.stopCircle, 
                              size: 14, 
                              color: _autoPlayNext ? theme.colorScheme.primary : theme.colorScheme.secondary
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '自动连播: ${_autoPlayNext ? "开" : "关"}', 
                              style: TextStyle(
                                fontSize: 11, 
                                fontWeight: FontWeight.bold,
                                color: _autoPlayNext ? theme.colorScheme.primary : theme.colorScheme.secondary
                              )
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 排序切换
                  GestureDetector(
                    onTap: () => setState(() => _descending = !_descending),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Row(
                        children: [
                          Icon(LucideIcons.arrowUpDown, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            _descending ? '倒序' : '正序', 
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, indent: 16, endIndent: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(group.urls.length, (i) {
                    final index = _descending ? (group.urls.length - 1 - i) : i;
                    final isCurrent = _currentEpisodeIndex == index;
                    final title = group.titles[index];
                    
                    return GestureDetector(
                      onTap: () => _handlePlayAction(index),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          constraints: const BoxConstraints(minWidth: 60),
                          decoration: BoxDecoration(
                            color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold, 
                              color: isCurrent ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white) : theme.colorScheme.onSurface
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceTab(ThemeData theme) {
    if (_availableSources.isEmpty && _isSearching) return const Center(child: CircularProgressIndicator());
    if (_availableSources.isEmpty) return Center(child: Text(_noSitesConfigured ? '未配置有效视频源' : '未搜到资源'));
    String statusText = '源站优选已完成';
    if (_isSearching) {
      statusText = '正在全网搜索源站...';
    } else if (_isOptimizing) statusText = '正在进行实时优选...';
    final currentSource = _currentSource;
    final otherSources = _availableSources.where((s) => s != currentSource).toList();
    otherSources.sort((a, b) => (_scoreMap['${b.source}-${b.id}'] ?? -1.0).compareTo(_scoreMap['${a.source}-${a.id}'] ?? -1.0));
    return Column(
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(statusText, style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary.withValues(alpha: 0.6))), GestureDetector(onTap: () => _optimizeBestSource(_availableSources), child: MouseRegion(cursor: SystemMouseCursors.click, child: Row(children: [Icon(LucideIcons.refreshCw, size: 12, color: theme.colorScheme.primary), const SizedBox(width: 4), Text('重新测速', style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.bold))])))])),
        Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [if (currentSource != null) ...[_buildSourceCard(theme, currentSource, isSelected: true), if (otherSources.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Row(children: [Expanded(child: Divider(color: theme.dividerColor)), const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('优选推荐', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))), Expanded(child: Divider(color: theme.dividerColor))]))], ...otherSources.map((res) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildSourceCard(theme, res, isSelected: false)))]))
      ],
    );
  }

  Widget _buildSourceCard(ThemeData theme, VideoDetail res, {required bool isSelected}) {
    final quality = _qualityInfoMap['${res.source}-${res.id}'];
    final score = _scoreMap['${res.source}-${res.id}'];
    return InkWell(
      onTap: () => _switchSource(res),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : theme.colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.4) : theme.dividerColor.withValues(alpha: 0.5), width: isSelected ? 1.5 : 1)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(child: Row(children: [Flexible(child: Text(res.sourceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold, fontSize: 14))), if (score != null && score >= 90) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: const Text('推荐', style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)))], if (quality != null && !quality.hasError) ...[const SizedBox(width: 6), _buildQualityBadge(quality.quality)]])),
              if (isSelected) Icon(LucideIcons.checkCircle2, size: 16, color: theme.colorScheme.primary),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Text('${res.playGroups.first.urls.length} 集', style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary.withValues(alpha: 0.6), fontWeight: FontWeight.w500)),
              const SizedBox(width: 16),
              if (quality != null && !quality.hasError) ...[_buildStatItem(LucideIcons.gauge, quality.loadSpeed, Colors.green), const SizedBox(width: 16), _buildStatItem(LucideIcons.activity, '${quality.pingTime}ms', Colors.orange)]
              else ...[_buildStatItem(LucideIcons.gauge, _isOptimizing ? '测速中' : '未知', Colors.green), const SizedBox(width: 16), _buildStatItem(LucideIcons.activity, _isOptimizing ? '测速中' : '未知', Colors.orange)],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityBadge(String quality) {
    Color color = Colors.green;
    if (quality.contains('4K')) color = Colors.purple;
    if (quality.contains('SD')) color = Colors.orange;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text(quality, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    final bool isTesting = text == '测速中';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: isTesting ? Colors.grey.withValues(alpha: 0.5) : color.withValues(alpha: 0.8)),
      const SizedBox(width: 4),
      isTesting ? SizedBox(width: 30, height: 2, child: LinearProgressIndicator(backgroundColor: Colors.transparent, color: color.withValues(alpha: 0.3))) : Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
    ]);
  }
}