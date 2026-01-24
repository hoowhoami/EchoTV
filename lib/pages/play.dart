import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../widgets/zen_ui.dart';

class PlayPage extends StatefulWidget {
  final String videoUrl;
  final String title;

  const PlayPage({Key? key, required this.videoUrl, required this.title}) : super(key: key);

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    initializePlayer();
  }

  Future<void> initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _videoPlayerController.initialize();
    
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
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
    setState(() {});
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
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
                : const CircularProgressIndicator(color: Colors.white),
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
