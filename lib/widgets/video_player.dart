import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/site.dart';
import '../services/ad_block_service.dart';
import '../providers/settings_provider.dart';
import 'video_controls.dart';

class EchoVideoPlayer extends ConsumerStatefulWidget {
  final String url;
  final String title;
  final String? referer;
  final bool isLive;
  final double? initialPosition;
  final SkipConfig? skipConfig;
  final Function(SkipConfig)? onSkipConfigChange;
  final VoidCallback? onNextEpisode;
  final bool hasNextEpisode;
  final Function(Duration)? onProgress;
  final VoidCallback? onEnded;

  const EchoVideoPlayer({
    super.key,
    required this.url,
    required this.title,
    this.referer,
    this.isLive = false,
    this.initialPosition,
    this.skipConfig,
    this.onSkipConfigChange,
    this.onNextEpisode,
    this.hasNextEpisode = false,
    this.onProgress,
    this.onEnded,
  });

  @override
  ConsumerState<EchoVideoPlayer> createState() => _EchoVideoPlayerState();
}

class _EchoVideoPlayerState extends ConsumerState<EchoVideoPlayer> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitializing = false;
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(EchoVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    if (_isInitializing || _isDisposed) return;
    setState(() => _isInitializing = true);

    try {
      final oldVideoController = _videoController;
      final oldChewieController = _chewieController;
      
      _videoController = null;
      _chewieController = null;

      if (oldChewieController != null) {
        oldChewieController.dispose();
      }
      if (oldVideoController != null) {
        oldVideoController.removeListener(_videoListener);
        await oldVideoController.dispose();
      }

      // 为了确保旧播放器资源完全释放，稍微等一下
      await Future.delayed(const Duration(milliseconds: 200));
      if (_isDisposed) return;

      // 核心修正：从 ref.read 改为 ref.read(adBlockEnabledProvider) 确保获取最新状态
      final isAdBlockEnabled = ref.read(adBlockEnabledProvider);
      final playUrl = isAdBlockEnabled 
          ? ref.read(adBlockServiceProvider).getProxyUrl(widget.url)
          : widget.url;

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(playUrl),
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
          if (widget.referer != null && widget.referer!.isNotEmpty) 'Referer': widget.referer!,
        },
        formatHint: widget.url.toLowerCase().contains('.m3u8') ? VideoFormat.hls : null,
      );
      
      _videoController = controller;
      await controller.initialize();
      if (_isDisposed) return;

      // 如果有初始进度，跳转
      if (widget.initialPosition != null && widget.initialPosition! > 0) {
        await controller.seekTo(Duration(seconds: widget.initialPosition!.toInt()));
      }

      // 设置音量
      final volume = ref.read(playerVolumeProvider);
      await controller.setVolume(volume);

      // 进度监听
      controller.addListener(_videoListener);

      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio,
        allowFullScreen: true,
        isLive: widget.isLive,
        customControls: ZenVideoControls(
          isAdBlockingEnabled: isAdBlockEnabled,
          onAdBlockingToggle: () {
            final currentEnabled = ref.read(adBlockEnabledProvider);
            ref.read(adBlockEnabledProvider.notifier).setEnabled(!currentEnabled);
            // 这里不需要手动调 _initializePlayer，因为下面 build 里的 watch 会处理
          },
          skipConfig: widget.skipConfig ?? SkipConfig(),
          onSkipConfigChange: widget.onSkipConfigChange,
          initialVolume: volume,
          onVolumeChanged: (vol) {
            ref.read(playerVolumeProvider.notifier).setVolume(vol);
          },
          hasNextEpisode: widget.hasNextEpisode,
          onNextEpisode: widget.onNextEpisode,
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: widget.isLive ? Colors.white : Theme.of(context).primaryColor,
          handleColor: widget.isLive ? Colors.white : Theme.of(context).primaryColor,
          bufferedColor: Colors.white.withOpacity(0.3),
          backgroundColor: Colors.white.withOpacity(0.1),
        ),
      );
    } catch (e) {
      debugPrint('EchoVideoPlayer error: $e');
    } finally {
      if (!_isDisposed) {
        setState(() => _isInitializing = false);
      }
    }
  }

  void _videoListener() {
    if (_videoController == null || _isDisposed) return;
    
    final value = _videoController!.value;
    
    // 进度回调
    if (widget.onProgress != null && value.isPlaying) {
      widget.onProgress!(value.position);
    }

    // --- 新增：跳过片头片尾逻辑 ---
    if (value.isPlaying && widget.skipConfig != null && widget.skipConfig!.enable) {
      final position = value.position.inSeconds;
      final duration = value.duration.inSeconds;

      // 跳过片头
      if (widget.skipConfig!.introTime > 0 && position < widget.skipConfig!.introTime) {
        _videoController!.seekTo(Duration(seconds: widget.skipConfig!.introTime));
        debugPrint('🛡️ 已跳过片头: ${widget.skipConfig!.introTime}s');
      }

      // 跳过片尾
      if (widget.skipConfig!.outroTime > 0 && duration > 0 && position > (duration - widget.skipConfig!.outroTime)) {
        debugPrint('🛡️ 已触碰片尾: ${widget.skipConfig!.outroTime}s');
        if (widget.onEnded != null) {
          widget.onEnded!();
        } else {
          _videoController!.pause();
        }
      }
    }

    // 结束回调
    if (value.position >= value.duration && value.duration > Duration.zero && !value.isPlaying) {
      if (widget.onEnded != null) {
        widget.onEnded!();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _chewieController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _videoController?.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 核心修正：监听去广告开关，变化时重新初始化播放器
    ref.listen(adBlockEnabledProvider, (previous, next) {
      if (previous != next) {
        _initializePlayer();
      }
    });

    if (_isInitializing || _chewieController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Chewie(controller: _chewieController!);
  }
}
