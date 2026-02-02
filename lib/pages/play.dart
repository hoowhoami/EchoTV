import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/video_player.dart';

class PlayPage extends ConsumerStatefulWidget {
  final String videoUrl;
  final String title;

  const PlayPage({super.key, required this.videoUrl, required this.title});

  @override
  ConsumerState<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends ConsumerState<PlayPage> {
  final GlobalKey _playerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: EchoVideoPlayer(
                  key: _playerKey,
                  url: widget.videoUrl,
                  title: widget.title,
                  isLive: true,
                  referer: widget.videoUrl.startsWith('http') ? Uri.parse(widget.videoUrl).origin : '',
                ),
              ),
            ),
            
            // Back button - 采用与点播页一致的简洁风格
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(LucideIcons.chevronLeft, size: 28, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}