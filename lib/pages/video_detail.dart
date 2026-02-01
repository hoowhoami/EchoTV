import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/movie.dart';
import '../models/site.dart';
import '../services/cms_service.dart';
import '../services/douban_service.dart';
import '../services/config_service.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../services/video_quality_service.dart';
import '../services/ad_block_service.dart';
import '../services/source_optimizer_service.dart';
import '../widgets/cover_image.dart';
import '../widgets/video_controls.dart';
import '../widgets/zen_ui.dart';

class VideoDetailPage extends ConsumerStatefulWidget {
  final DoubanSubject subject;

  const VideoDetailPage({super.key, required this.subject});

  @override
  ConsumerState<VideoDetailPage> createState() => _VideoDetailPageState();
}

enum LoadingStage { searching, preferring, fetching, ready }

class _VideoDetailPageState extends ConsumerState<VideoDetailPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  DoubanSubject? _fullSubject;
  late TabController _tabController;
  late String _doubanId;

  List<VideoDetail> _availableSources = [];
  VideoDetail? _currentSource;
  int _currentEpisodeIndex = 0;
  double? _initialResumePosition;
  bool _isSearching = true;
  bool _isDetailLoading = true;
  bool _isOptimizing = false;
  bool _isInitializing = false;
  LoadingStage _loadingStage = LoadingStage.searching;
  String _loadingMessage = '🔍 正在搜索播放源...';

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isPlaying = false;
  bool _autoPlayNext = true;

  final Map<String, VideoQualityInfo> _qualityInfoMap = {};
  final Map<String, double> _scoreMap = {};
  final Set<String> _testedSources = {};

  bool _descending = false;
  bool _isEpisodeSelectorCollapsed = false;
  
  // Skip Config and Ad Blocking
  SkipConfig _skipConfig = SkipConfig();
  bool _isAdBlockingEnabled = true;

  // 移除 Timer，改用状态位控制
  bool _hasTriggeredInitialInit = false;

  @override
  void initState() {
    super.initState();
    _doubanId = widget.subject.id;
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _loadSettings();
    _checkHistoryAndLoadData();
    WakelockPlus.enable();
  }

  void _loadSettings() async {
    final configService = ref.read(configServiceProvider);
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdBlockingEnabled = prefs.getBool('enable_blockad') ?? true;
    });
  }

  void _loadSkipConfig() async {
    if (_currentSource == null) return;
    final configService = ref.read(configServiceProvider);
    final key = '${_currentSource!.source}-${_currentSource!.id}';
    final configs = await configService.getSkipConfigs();
    if (configs.containsKey(key)) {
      setState(() {
        _skipConfig = configs[key]!;
      });
    } else {
      setState(() {
        _skipConfig = SkipConfig();
      });
    }
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

    if (_doubanId.isNotEmpty) {
      doubanService.getDetail(_doubanId).then((val) {
        if (val == null) {
          debugPrint('⚠️ 豆瓣详情获取为空: id=$_doubanId');
        } else {
          debugPrint('✅ 豆瓣详情获取成功: ${val.title}');
        }
        if (mounted) {
          setState(() {
            _fullSubject = val ?? widget.subject;
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

    await for (final results in cmsService.searchAllStream(sites, widget.subject.title)) {
      if (!mounted) break;

      final List<VideoDetail> filtered = [];
      final seenKeys = <String>{};
      
      for (var res in results) {
        final sTitle = res.title.replaceAll(' ', '').toLowerCase();
        final tTitle = widget.subject.title.replaceAll(' ', '').toLowerCase();
        if (sTitle.contains(tTitle) || tTitle.contains(sTitle)) {
          final key = '${res.source}-${res.id}';
          if (!seenKeys.contains(key)) {
            seenKeys.add(key);
            filtered.add(res);
          }
        }
      }

      if (mounted) {
        setState(() {
          _availableSources = filtered;
          // 兜底逻辑：如果豆瓣没抓到描述，且已经有了资源结果，使用第一个有描述的资源的详情
          if ((_fullSubject?.description == null || _fullSubject!.description!.isEmpty) && filtered.isNotEmpty) {
            final firstWithDesc = filtered.firstWhere((e) => e.desc != null && e.desc!.isNotEmpty, orElse: () => filtered.first);
            if (firstWithDesc.desc != null && firstWithDesc.desc!.isNotEmpty) {
              _fullSubject = DoubanSubject(
                id: _doubanId,
                title: widget.subject.title,
                rate: widget.subject.rate,
                cover: widget.subject.cover,
                year: widget.subject.year,
                description: firstWithDesc.desc,
              );
              _isDetailLoading = false;
            }
          }
        });
        
        // 核心改变：启动动态初始化监测
        if (!_hasTriggeredInitialInit && filtered.isNotEmpty) {
          _hasTriggeredInitialInit = true;
          _startDynamicInitialization();
        }

        if (filtered.isNotEmpty && !_isOptimizing) {
          _optimizeBestSource(filtered);
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
      if (!mounted || _isPlaying || _isInitializing) return;

      final bool hasHighQualitySource = _scoreMap.values.any((score) => score >= 90);
      final bool hasEnoughSamples = _testedSources.length >= 3 || _testedSources.length == _availableSources.length;
      final bool isSearchDone = !_isSearching;

      if (hasHighQualitySource || (isSearchDone && hasEnoughSamples) || tick >= 15) {
        break;
      }

      await Future.delayed(const Duration(milliseconds: 200));
      tick++;
    }

    if (mounted && _availableSources.isNotEmpty && !_isPlaying && !_isInitializing) {
      setState(() {
        _loadingStage = LoadingStage.preferring;
        _loadingMessage = '⚡ 正在优选最佳线路...';
      });

      final optimizer = ref.read(sourceOptimizerServiceProvider);
      final result = await optimizer.selectBestSource(_availableSources, cachedQualityInfo: _qualityInfoMap);
      
      if (mounted) {
        setState(() {
          _currentSource = result.bestSource;
          _qualityInfoMap.addAll(result.qualityInfoMap);
          _scoreMap.addAll(result.scoreMap);
          _loadingStage = LoadingStage.fetching;
          _loadingMessage = '🎬 正在准备播放...';
        });
        
        _loadSkipConfig();
        _initializePlayer(
          _currentSource!.playGroups.first.urls[_currentEpisodeIndex], 
          _currentEpisodeIndex, 
          resumePosition: _initialResumePosition,
          autoPlay: true, 
        );
        // 使用后清空初始进度，防止干扰手动切换
        _initialResumePosition = null;
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

    Future<void> _initializePlayer(String url, int index, {double? resumePosition, bool autoPlay = true}) async {

      if (_isInitializing) return;

      

      _isInitializing = true;

      if (mounted) setState(() {});

  

      try {

        // 彻底销毁旧的控制器

        final oldPlayer = _videoController;

        final oldChewie = _chewieController;

        _videoController = null;

        _chewieController = null;

        _isPlaying = false; // 重置播放状态

        if (mounted) setState(() {});

        

        oldChewie?.dispose();

        await oldPlayer?.dispose();

        

                await Future.delayed(const Duration(milliseconds: 300));

        

        

        

                if (!mounted) return;

        

        

        

                // 如果开启去广告，则通过本地代理处理 M3U8

        

                final playUrl = _isAdBlockingEnabled 

        

                    ? ref.read(adBlockServiceProvider).getProxyUrl(url) 

        

                    : url;

        

        

        

                final controller = VideoPlayerController.networkUrl(

        

                  Uri.parse(playUrl),

        

                  videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),

          httpHeaders: {

            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',

            'Referer': url.startsWith('http') ? Uri.parse(url).origin : '',

          },

          formatHint: url.toLowerCase().contains('.m3u8') ? VideoFormat.hls : null,

        );

        _videoController = controller;

  

        controller.addListener(() {

          if (!mounted || _videoController != controller) return;

          

          if (controller.value.hasError) {

            final error = controller.value.errorDescription;

            debugPrint('播放器运行时错误: $error');

            _handlePlaybackFailure(url, index, resumePosition: controller.value.position.inSeconds.toDouble(), autoPlay: true);

            return;

          }

  

          if (!controller.value.isInitialized) return;

          

          if (mounted && _isPlaying != controller.value.isPlaying) {
            setState(() {
              _isPlaying = controller.value.isPlaying;
            });
          }

          if (controller.value.isPlaying && controller.value.position.inSeconds % 5 == 0) _savePlayRecord();

          

          // Skip intro/outro logic

          if (controller.value.isPlaying && _skipConfig.enable) {

            final position = controller.value.position.inSeconds;

            final duration = controller.value.duration.inSeconds;

            

            // Skip intro

            if (_skipConfig.introTime > 0 && position < _skipConfig.introTime) {

              controller.seekTo(Duration(seconds: _skipConfig.introTime));

              debugPrint('已跳过片头: ${_skipConfig.introTime}s');

            }

            

            // Skip outro

            if (_skipConfig.outroTime > 0 && duration > 0 && position > (duration - _skipConfig.outroTime)) {

               if (_autoPlayNext) {

                 _playNextEpisode();

               } else {

                 controller.pause();

               }

               debugPrint('已跳过片尾: ${_skipConfig.outroTime}s');

            }

          }

  

          if (controller.value.position >= controller.value.duration && controller.value.duration > Duration.zero && !controller.value.isPlaying) {

            if (_autoPlayNext) _playNextEpisode();

          }

        });

  

                                await controller.initialize().timeout(const Duration(seconds: 30));

  

                                

  

                                // 设置初始音量为全局记忆值

  

                                final globalVolume = ref.read(playerVolumeProvider);

  

                                await controller.setVolume(globalVolume);

  

                                

  

                                if (resumePosition != null && resumePosition > 1) {

          await controller.seekTo(Duration(seconds: resumePosition.toInt()));

        }

  

        if (mounted && _videoController == controller) {

          _createChewieController(autoPlay: autoPlay);

          _isInitializing = false; // 初始化成功

          setState(() {

            _currentEpisodeIndex = index;

          });

        }

      } catch (e) {

        debugPrint('播放器初始化失败: $e');

        if (mounted) {

          await _handlePlaybackFailure(url, index, resumePosition: resumePosition, autoPlay: autoPlay);

        }

      } finally {

        if (mounted) {

          _isInitializing = false;

          if (mounted) setState(() {});

        }

      }

    }

  

    /// 统一处理播放失败

    Future<void> _handlePlaybackFailure(String url, int index, {double? resumePosition, bool autoPlay = true}) async {

      if (!mounted) return;

  

      // 标记当前源为故障

      final key = '${_currentSource?.source}-${_currentSource?.id}';

      _qualityInfoMap[key] = VideoQualityInfo.error();

      _scoreMap[key] = -1.0; 

      

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('当前线路连接失败，请尝试手动切换源站'), backgroundColor: Colors.redAccent)

        );

        setState(() {

          _isInitializing = false;

          _isPlaying = false;

        });

      }

    }

  void _createChewieController({bool autoPlay = true}) {
    if (!mounted || _videoController == null) return;
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: autoPlay,
      aspectRatio: _videoController!.value.aspectRatio,
      allowFullScreen: true,
      customControls: ZenVideoControls(
        isAdBlockingEnabled: _isAdBlockingEnabled,
        onAdBlockingToggle: () async {
          final prefs = await SharedPreferences.getInstance();
          setState(() {
            _isAdBlockingEnabled = !_isAdBlockingEnabled;
            prefs.setBool('enable_blockad', _isAdBlockingEnabled);
          });
          _handlePlayAction(_currentEpisodeIndex, resumePosition: _videoController?.value.position.inSeconds.toDouble());
        },
        skipConfig: _skipConfig,
        onSkipConfigChange: (newConfig) async {
          final key = '${_currentSource!.source}-${_currentSource!.id}';
          await ref.read(configServiceProvider).saveSkipConfig(key, newConfig);
          setState(() => _skipConfig = newConfig);
        },
        initialVolume: ref.read(playerVolumeProvider),
        onVolumeChanged: (vol) {
          ref.read(playerVolumeProvider.notifier).setVolume(vol);
        },
        hasNextEpisode: _currentSource != null && _currentEpisodeIndex < _currentSource!.playGroups.first.urls.length - 1,
        onNextEpisode: _playNextEpisode,
      ),
      materialProgressColors: ChewieProgressColors(
        playedColor: Theme.of(context).primaryColor,
        handleColor: Theme.of(context).primaryColor,
      ),
    );
    _isPlaying = autoPlay;
    if (autoPlay) _savePlayRecord();
  }

  Future<void> _savePlayRecord() async {
    if (_currentSource == null || _videoController == null) return;
    final record = PlayRecord(
      title: widget.subject.title,
      sourceName: _currentSource!.sourceName,
      cover: widget.subject.cover,
      year: widget.subject.year ?? '',
      index: _currentEpisodeIndex,
      totalEpisodes: _currentSource!.playGroups.first.urls.length,
      playTime: _videoController!.value.position.inSeconds,
      totalTime: _videoController!.value.duration.inSeconds,
      saveTime: DateTime.now().millisecondsSinceEpoch,
      searchTitle: widget.subject.title,
      doubanId: _doubanId,
    );
    ref.read(historyProvider.notifier).saveRecord(record);
  }

  void _playNextEpisode() {
    if (_currentSource == null) return;
    final nextIndex = _currentEpisodeIndex + 1;
    if (nextIndex < _currentSource!.playGroups.first.urls.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('即将播放：${_currentSource!.playGroups.first.titles[nextIndex]}'), behavior: SnackBarBehavior.floating));
      _handlePlayAction(nextIndex);
    }
  }

  void _playPreviousEpisode() {
    if (_currentSource == null) return;
    final prevIndex = _currentEpisodeIndex - 1;
    if (prevIndex >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('即将播放：${_currentSource!.playGroups.first.titles[prevIndex]}'), behavior: SnackBarBehavior.floating));
      _handlePlayAction(prevIndex);
    }
  }

  void _handlePlayAction(int index, {double? resumePosition}) {
    if (_currentSource == null) return;
    // 手动操作，清除初始恢复进度
    _initialResumePosition = null;
    _initializePlayer(_currentSource!.playGroups.first.urls[index], index, resumePosition: resumePosition, autoPlay: true);
  }

  Future<void> _switchSource(VideoDetail newSource) async {
    // 手动操作，清除初始恢复进度
    _initialResumePosition = null;
    final oldPlayPosition = _videoController?.value.position.inSeconds.toDouble() ?? 0.0;
    setState(() {
      _currentSource = newSource;
      // 不要在这里设置 _isInitializing = true，因为 _initializePlayer 内部会处理并检查它
    });
    _loadSkipConfig();
    final targetIndex = _currentEpisodeIndex >= newSource.playGroups.first.urls.length ? 0 : _currentEpisodeIndex;
    _initializePlayer(newSource.playGroups.first.urls[targetIndex], targetIndex, resumePosition: oldPlayPosition, autoPlay: _isPlaying);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // 切到后台：仅暂停并强制保存一次进度，不销毁实例
      _videoController?.pause();
      _savePlayRecord();
    } else if (state == AppLifecycleState.detached) {
      // 彻底断开（如热重启）：销毁所有资源
      _videoController?.dispose();
      _videoController = null;
      _chewieController?.dispose();
      _chewieController = null;
      _isPlaying = false;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPC = screenWidth > 800;
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
    final bool hasError = !_isSearching && _currentSource != null && _chewieController == null && !_isOptimizing && !_isInitializing;
    final content = _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
        ? Chewie(controller: _chewieController!)
        : Stack(
            children: [
              Positioned.fill(child: CoverImage(imageUrl: widget.subject.cover)),
              Container(color: Colors.black.withValues(alpha: 0.6)),
              Center(
                child: hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.alertCircle, color: Colors.white60, size: 40),
                          const SizedBox(height: 12),
                          const Text('播放失败，请切换源站', style: TextStyle(color: Colors.white70)),
                          TextButton(onPressed: () => _switchSource(_currentSource!), child: const Text('重试')),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            _loadingMessage,
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ],
          );

    final playerContainer = Container(
      height: isPC ? _calculatePlayerHeight(MediaQuery.of(context).size.width) : null,
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 20))]),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
    return isPC ? playerContainer : AspectRatio(aspectRatio: 16 / 9, child: playerContainer);
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
                if (widget.subject.rate.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text('⭐ ${widget.subject.rate}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14))),
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
    if (_fullSubject?.description != null && _fullSubject!.description!.isNotEmpty) {
      return Text(
        _fullSubject!.description!, 
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
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4), 
          fontSize: 14,
          fontStyle: FontStyle.italic
        )
      );
    }

    // 骨架屏占位
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: i == 2 ? 200 : double.infinity,
          height: 14,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      )),
    );
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
      return const Center(child: Text('暂无资源'));
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
                    final isCurrent = _currentEpisodeIndex == index && (_chewieController != null || _isInitializing);
                    final title = group.titles[index];
                    
                    return GestureDetector(
                      onTap: _isInitializing ? null : () => _handlePlayAction(index),
                      child: MouseRegion(
                        cursor: _isInitializing ? SystemMouseCursors.basic : SystemMouseCursors.click,
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
        if (_isInitializing)
          Positioned.fill(
            child: Container(
              color: theme.colorScheme.surface.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSourceTab(ThemeData theme) {
    if (_availableSources.isEmpty && _isSearching) return const Center(child: CircularProgressIndicator());
    if (_availableSources.isEmpty) return const Center(child: Text('未搜到资源'));
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