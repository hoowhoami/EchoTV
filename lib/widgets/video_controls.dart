import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';
import '../models/site.dart';

class ZenVideoControls extends StatefulWidget {
  final bool isAdBlockingEnabled;
  final VoidCallback? onAdBlockingToggle;
  final VoidCallback? onNextEpisode;
  final bool hasNextEpisode;
  final SkipConfig skipConfig;
  final Function(SkipConfig)? onSkipConfigChange;

  const ZenVideoControls({
    super.key,
    this.isAdBlockingEnabled = true,
    this.onAdBlockingToggle,
    this.onNextEpisode,
    this.hasNextEpisode = false,
    required this.skipConfig,
    this.onSkipConfigChange,
  });

  @override
  State<ZenVideoControls> createState() => _ZenVideoControlsState();
}

class _ZenVideoControlsState extends State<ZenVideoControls> with WindowListener {
  VideoPlayerValue? _latestValue;
  Timer? _hideTimer;
  bool _displayToggles = false;
  bool _showSettings = false;
  bool _showSpeedSubMenu = false;
  bool _isBarHovered = false;
  final double _barHeight = 36.0;
  
  late SkipConfig _localSkipConfig;
  
  ChewieController? _chewieController;
  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    _localSkipConfig = widget.skipConfig;
    windowManager.addListener(this);
  }

  @override
  void didUpdateWidget(ZenVideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.skipConfig != widget.skipConfig) {
      setState(() {
        _localSkipConfig = widget.skipConfig;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newChewieController = ChewieController.of(context);
    if (_chewieController != newChewieController) {
      _videoPlayerController?.removeListener(_updateState);
      _chewieController = newChewieController;
      _videoPlayerController = newChewieController.videoPlayerController;
      _latestValue = _videoPlayerController?.value;
      _videoPlayerController?.addListener(_updateState);
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_updateState);
    _hideTimer?.cancel();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowLeaveFullScreen() {
    if (_chewieController?.isFullScreen ?? false) {
      _chewieController?.exitFullScreen();
    }
  }

  void _updateState() {
    if (mounted && _videoPlayerController != null) {
      setState(() {
        _latestValue = _videoPlayerController!.value;
      });
    }
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();
    setState(() {
      _displayToggles = true;
    });
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _displayToggles = false;
          _showSettings = false;
          _showSpeedSubMenu = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_latestValue?.hasError ?? false) {
      return const Center(child: Icon(LucideIcons.alertCircle, color: Colors.white, size: 32));
    }

    return MouseRegion(
      onHover: (_) => _cancelAndRestartTimer(),
      child: GestureDetector(
        onTap: () {
          if (_showSettings) {
            setState(() {
              _showSettings = false;
              _showSpeedSubMenu = false;
            });
          } else {
            _cancelAndRestartTimer();
          }
        },
        child: AbsorbPointer(
          absorbing: !_displayToggles && !_showSettings,
          child: Stack(
            children: [
              if (_latestValue == null || !_latestValue!.isInitialized || _latestValue!.isBuffering)
                const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              
              _buildHitArea(),
              
              if (_showSettings) _buildSettingsOverlay(),

              if (!_showSettings)
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    _buildBottomBar(context),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsOverlay() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: 220,
        color: Colors.black.withOpacity(0.9),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_showSpeedSubMenu) {
                        setState(() => _showSpeedSubMenu = false);
                      } else {
                        setState(() => _showSettings = false);
                      }
                    },
                    child: const Icon(LucideIcons.chevronLeft, color: Colors.white70, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _showSpeedSubMenu ? '播放倍速' : '播放设置',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: _showSpeedSubMenu ? _buildSpeedList() : _buildMainSettingsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainSettingsList() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildSettingItem(
          title: '播放倍速',
          subtitle: '${_latestValue?.playbackSpeed}x',
          trailing: const Icon(LucideIcons.chevronRight, color: Colors.white38, size: 14),
          onTap: () => setState(() => _showSpeedSubMenu = true),
        ),
        _buildSettingItem(
          title: '去广告',
          trailing: Transform.scale(
            scale: 0.6,
            child: Switch(
              value: widget.isAdBlockingEnabled,
              onChanged: (val) => widget.onAdBlockingToggle?.call(),
              activeColor: Theme.of(context).primaryColor,
            ),
          ),
        ),
        _buildSettingItem(
          title: '跳过片头片尾',
          trailing: Transform.scale(
            scale: 0.6,
            child: Switch(
              value: _localSkipConfig.enable,
              onChanged: (val) {
                final newConfig = SkipConfig(
                  enable: val,
                  introTime: _localSkipConfig.introTime,
                  outroTime: _localSkipConfig.outroTime,
                );
                setState(() => _localSkipConfig = newConfig);
                widget.onSkipConfigChange?.call(newConfig);
              },
              activeColor: Theme.of(context).primaryColor,
            ),
          ),
        ),
        const Divider(color: Colors.white12, height: 10),
        _buildSettingItem(
          title: '设当前为片头',
          subtitle: _localSkipConfig.introTime > 0 ? '${_localSkipConfig.introTime}s' : '未设置',
          onTap: () {
            final currentPos = _videoPlayerController?.value.position.inSeconds ?? 0;
            final newConfig = SkipConfig(
              enable: true,
              introTime: currentPos,
              outroTime: _localSkipConfig.outroTime,
            );
            setState(() => _localSkipConfig = newConfig);
            widget.onSkipConfigChange?.call(newConfig);
          },
        ),
        _buildSettingItem(
          title: '设当前为片尾',
          subtitle: _localSkipConfig.outroTime > 0 ? '倒数 ${_localSkipConfig.outroTime}s' : '未设置',
          onTap: () {
            final currentPos = _videoPlayerController?.value.position.inSeconds ?? 0;
            final total = _videoPlayerController?.value.duration.inSeconds ?? 0;
            if (total > 0) {
              final newConfig = SkipConfig(
                enable: true,
                introTime: _localSkipConfig.introTime,
                outroTime: total - currentPos,
              );
              setState(() => _localSkipConfig = newConfig);
              widget.onSkipConfigChange?.call(newConfig);
            }
          },
        ),
        _buildSettingItem(
          title: '重置跳过设置',
          onTap: () {
            const newConfig = SkipConfig(enable: false, introTime: 0, outroTime: 0);
            setState(() => _localSkipConfig = newConfig);
            widget.onSkipConfigChange?.call(newConfig);
          },
          textColor: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildSpeedList() {
    final List<double> speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];
    return ListView(
      padding: EdgeInsets.zero,
      children: speeds.map((speed) {
        final isSelected = _latestValue?.playbackSpeed == speed;
        return _buildSettingItem(
          title: '${speed}x',
          textColor: isSelected ? Theme.of(context).primaryColor : Colors.white,
          trailing: isSelected ? Icon(LucideIcons.check, color: Theme.of(context).primaryColor, size: 14) : null,
          onTap: () {
            _videoPlayerController?.setPlaybackSpeed(speed);
            setState(() => _showSpeedSubMenu = false);
          },
        );
      }).toList(),
    );
  }

  Widget _buildSettingItem({required String title, String? subtitle, Widget? trailing, VoidCallback? onTap, Color? textColor}) {
    return ListTile(
      title: Text(title, style: TextStyle(color: textColor ?? Colors.white, fontSize: 13)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)) : null,
      trailing: trailing,
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return AnimatedOpacity(
      opacity: _displayToggles ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgressBar(),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_videoPlayerController != null) _buildPlayPause(_videoPlayerController!),
                if (widget.hasNextEpisode && widget.onNextEpisode != null)
                  _buildIconBtn(LucideIcons.stepForward, widget.onNextEpisode!),
                if (_videoPlayerController != null) _buildVolumeButton(context),
                const SizedBox(width: 8),
                _buildPosition(context),
                
                const Spacer(),
                
                // 右侧组合：[设置] [应用全屏] [桌面全屏]
                _buildIconBtn(LucideIcons.settings, () {
                  setState(() {
                    _showSettings = true;
                    _displayToggles = true;
                  });
                }),

                _buildIconBtn(LucideIcons.expand, () {
                  _chewieController?.toggleFullScreen();
                }),

                if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux))
                  _buildIconBtn(LucideIcons.maximize, () async {
                    bool isFullScreen = await windowManager.isFullScreen();
                    if (!isFullScreen) {
                      if (!(_chewieController?.isFullScreen ?? false)) {
                        _chewieController?.enterFullScreen();
                      }
                      await windowManager.setFullScreen(true);
                    } else {
                      await windowManager.setFullScreen(false);
                      if (_chewieController?.isFullScreen ?? false) {
                        _chewieController?.exitFullScreen();
                      }
                    }
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return _HoverableIcon(icon: icon, onTap: onTap);
  }

  Widget _buildVolumeButton(BuildContext context) {
    final volume = _videoPlayerController?.value.volume ?? 1.0;
    IconData iconData = LucideIcons.volume2;
    if (volume == 0) {
      iconData = LucideIcons.volumeX;
    } else if (volume < 0.5) iconData = LucideIcons.volume1;

    return _HoverableIcon(
      icon: iconData, 
      onTap: () {
        final newVol = (volume == 0) ? 1.0 : 0.0;
        _videoPlayerController?.setVolume(newVol);
      }
    );
  }

  Widget _buildHitArea() {
    return GestureDetector(
      onTap: () {
        if (_showSettings) {
          setState(() {
            _showSettings = false;
            _showSpeedSubMenu = false;
          });
        } else if (_displayToggles) {
          setState(() => _displayToggles = false);
        } else {
          _cancelAndRestartTimer();
        }
      },
      child: Container(color: Colors.transparent),
    );
  }

  Widget _buildPlayPause(VideoPlayerController controller) {
    return _HoverableIcon(
      icon: controller.value.isPlaying ? LucideIcons.pause : LucideIcons.play,
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
        _cancelAndRestartTimer();
      },
      size: 20,
    );
  }

  Widget _buildPosition(BuildContext context) {
    final position = _latestValue?.position ?? Duration.zero;
    final duration = _latestValue?.duration ?? Duration.zero;
    return Text(
      '${_formatDuration(position)} / ${_formatDuration(duration)}',
      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w400),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildProgressBar() {
    if (_videoPlayerController == null) return const SizedBox.shrink();
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isBarHovered = true),
      onExit: (_) => setState(() => _isBarHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _isBarHovered ? 12 : 8,
        alignment: Alignment.center,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: _isBarHovered ? 4.0 : 2.0,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: _isBarHovered ? 6.0 : 0.0,
              elevation: 0,
              pressedElevation: 0,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
            activeTrackColor: Theme.of(context).primaryColor,
            inactiveTrackColor: Colors.white.withOpacity(0.15),
            thumbColor: Theme.of(context).primaryColor,
            trackShape: const RectangularSliderTrackShape(),
          ),
          child: Slider(
            value: _videoPlayerController!.value.position.inMilliseconds.toDouble().clamp(
              0.0, 
              _videoPlayerController!.value.duration.inMilliseconds.toDouble()
            ),
            max: _videoPlayerController!.value.duration.inMilliseconds.toDouble(),
            onChanged: (value) {
              _videoPlayerController!.seekTo(Duration(milliseconds: value.toInt()));
            },
            onChangeStart: (_) => _hideTimer?.cancel(),
            onChangeEnd: (_) => _cancelAndRestartTimer(),
          ),
        ),
      ),
    );
  }
}

class _HoverableIcon extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _HoverableIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 18,
  });

  @override
  State<_HoverableIcon> createState() => _HoverableIconState();
}

class _HoverableIconState extends State<_HoverableIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Icon(
              widget.icon,
              color: _isHovered ? Colors.white : Colors.white.withOpacity(0.85),
              size: widget.size,
            ),
          ),
        ),
      ),
    );
  }
}
