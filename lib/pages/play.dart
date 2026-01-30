import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../widgets/zen_ui.dart';

class PlayPage extends StatefulWidget {
  final String videoUrl;
  final String title;

  const PlayPage({Key? key, required this.videoUrl, required this.title}) : super(key: key);

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitializing = false;
  int _retryCount = 0;
  static const int _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    initializePlayer();
    // 开启唤醒锁，防止播放时锁屏
    WakelockPlus.enable();
  }

  Future<void> initializePlayer() async {
    if (_isInitializing && _retryCount == 0) return;
    setState(() => _isInitializing = true);

    try {
      final oldPlayer = _videoPlayerController;
      final oldChewie = _chewieController;
      _videoPlayerController = null;
      _chewieController = null;
      
      oldChewie?.dispose();
      await oldPlayer?.dispose();
      await Future.delayed(const Duration(milliseconds: 200));

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
          'Referer': widget.videoUrl.startsWith('http') ? Uri.parse(widget.videoUrl).origin : '',
        },
        formatHint: widget.videoUrl.toLowerCase().contains('.m3u8') ? VideoFormat.hls : null,
      );
      _videoPlayerController = controller;

      await controller.initialize().timeout(const Duration(seconds: 15));
      
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Colors.white,
          bufferedColor: Colors.white.withOpacity(0.3),
          backgroundColor: Colors.white.withOpacity(0.1),
        ),
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Colors.white,
          bufferedColor: Colors.white.withOpacity(0.3),
          backgroundColor: Colors.white.withOpacity(0.1),
        ),
      );
      _retryCount = 0;
    } catch (e) {
      debugPrint('PlayPage 初始化失败: $e');
      if (mounted) {
        if (_retryCount < _maxRetries) {
          _retryCount++;
          await Future.delayed(Duration(milliseconds: 800 * _retryCount));
          return initializePlayer();
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('播放失败: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    // 页面销毁时关闭唤醒锁，恢复系统默认设置
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      if (_retryCount > 0) ...[
                        const SizedBox(height: 16),
                        Text('正在尝试重试 ($_retryCount/$_maxRetries)...', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ]
                    ],
                  ),
          ),
          
          // Back button
          Positioned(
            top: 40,
            left: 20,
            child: ZenButton(
              padding: const EdgeInsets.all(12),
              borderRadius: 20,
              backgroundColor: Colors.black.withOpacity(0.5),
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
