import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';
import '../models/site.dart';
import 'zen_ui.dart';

class ZenVideoControls extends StatefulWidget {
  final bool isAdBlockingEnabled;
  final VoidCallback? onAdBlockingToggle;
  final VoidCallback? onNextEpisode;
  final bool hasNextEpisode;
  final SkipConfig skipConfig;
  final Function(SkipConfig)? onSkipConfigChange;
  final double initialVolume;
  final Function(double)? onVolumeChanged;

  const ZenVideoControls({
    super.key,
    this.isAdBlockingEnabled = true,
    this.onAdBlockingToggle,
    this.onNextEpisode,
    this.hasNextEpisode = false,
    required this.skipConfig,
    this.onSkipConfigChange,
    this.initialVolume = 0.5,
    this.onVolumeChanged,
  });

  @override
  State<ZenVideoControls> createState() => _ZenVideoControlsState();
}

class _ZenVideoControlsState extends State<ZenVideoControls> with WindowListener {
  VideoPlayerValue? _latestValue;
  Timer? _hideTimer;
  Timer? _hintTimer;
  bool _displayToggles = false;
  bool _showSettings = false;
  bool _showSpeedSubMenu = false;
  bool _isBarHovered = false;
  bool _isLocked = false;
  bool _showVolumeSlider = false;
  double _lastVolume = 0.5;
  bool _showHint = false;
  String _hintText = '';
  IconData _hintIcon = LucideIcons.play;
  final double _barHeight = 36.0;
  
  late SkipConfig _localSkipConfig;
  
  ChewieController? _chewieController;
  VideoPlayerController? _videoPlayerController;

  @override
  void initState() {
    super.initState();
    _localSkipConfig = widget.skipConfig;
    _lastVolume = widget.initialVolume;
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
    _hintTimer?.cancel();
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
      if (mounted && !_showSettings) {
        setState(() {
          _displayToggles = false;
        });
      }
    });
  }

  void _showActionHint(String text, IconData icon) {
    _hintTimer?.cancel();
    setState(() {
      _hintText = text;
      _hintIcon = icon;
      _showHint = true;
    });
    _hintTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || _videoPlayerController == null) return;
    
    final key = event.logicalKey;
    if (_isLocked && key != LogicalKeyboardKey.keyL) return;

    if (key == LogicalKeyboardKey.space) {
      if (_videoPlayerController!.value.isPlaying) {
        _videoPlayerController!.pause();
        _showActionHint('已暂停', LucideIcons.pause);
      } else {
        _videoPlayerController!.play();
        _showActionHint('已播放', LucideIcons.play);
      }
      _cancelAndRestartTimer();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      final newPos = _videoPlayerController!.value.position - const Duration(seconds: 10);
      _videoPlayerController!.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
      _showActionHint('-10s', LucideIcons.rewind);
      _cancelAndRestartTimer();
    } else if (key == LogicalKeyboardKey.arrowRight) {
      final newPos = _videoPlayerController!.value.position + const Duration(seconds: 10);
      _videoPlayerController!.seekTo(newPos);
      _showActionHint('+10s', LucideIcons.fastForward);
      _cancelAndRestartTimer();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      final newVol = (_videoPlayerController!.value.volume + 0.1).clamp(0.0, 1.0);
      _videoPlayerController!.setVolume(newVol);
      if (newVol > 0) _lastVolume = newVol;
      _showActionHint('音量: ${(newVol * 100).toInt()}%', newVol == 0 ? LucideIcons.volumeX : (newVol < 0.5 ? LucideIcons.volume1 : LucideIcons.volume2));
      _cancelAndRestartTimer();
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final newVol = (_videoPlayerController!.value.volume - 0.1).clamp(0.0, 1.0);
      _videoPlayerController!.setVolume(newVol);
      if (newVol > 0) _lastVolume = newVol;
      _showActionHint('音量: ${(newVol * 100).toInt()}%', newVol == 0 ? LucideIcons.volumeX : (newVol < 0.5 ? LucideIcons.volume1 : LucideIcons.volume2));
      _cancelAndRestartTimer();
    } else if (key == LogicalKeyboardKey.keyL) {
      setState(() => _isLocked = !_isLocked);
      _showActionHint(_isLocked ? '已上锁' : '已解锁', _isLocked ? LucideIcons.lock : LucideIcons.unlock);
      _cancelAndRestartTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_latestValue?.hasError ?? false) {
      return const Center(child: Icon(LucideIcons.alertCircle, color: Colors.white, size: 32));
    }

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onHover: (_) => _cancelAndRestartTimer(),
        child: GestureDetector(
          onTap: () {
            if (_isLocked) {
              _cancelAndRestartTimer();
              return;
            }
            if (_showSettings) {
              setState(() {
                _showSettings = false;
                _showSpeedSubMenu = false;
                _startHideTimer();
              });
            } else if (_displayToggles) {
              setState(() => _displayToggles = false);
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

                // 中央提示
                if (_showHint)
                  Center(
                    child: AnimatedOpacity(
                      opacity: _showHint ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_hintIcon, color: Colors.white, size: 32),
                            const SizedBox(height: 8),
                            Text(_hintText, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                if (_showSettings && !_isLocked) _buildSettingsOverlay(),

                if (!_showSettings) ...[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _buildTopBar(context),
                      _buildBottomBar(context),
                    ],
                  ),
                  _buildLockButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockButton() {
    return AnimatedOpacity(
      opacity: _displayToggles ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 24),
          child: _buildIconBtn(
            _isLocked ? LucideIcons.lock : LucideIcons.unlock,
            () {
              setState(() => _isLocked = !_isLocked);
              _showActionHint(_isLocked ? '已上锁' : '已解锁', _isLocked ? LucideIcons.lock : LucideIcons.unlock);
              _cancelAndRestartTimer();
            },
            size: 26,
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
      child: GestureDetector(
        onTap: () {}, // 拦截点击，防止冒泡到顶层导致面板关闭
        behavior: HitTestBehavior.opaque,
        child: Theme(
          data: ThemeData(brightness: Brightness.dark),
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
                            setState(() {
                              _showSettings = false;
                              _startHideTimer();
                            });
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
        ),
      ),
    );
  }

  Widget _buildMainSettingsList() {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildSettingItem(
          title: '播放倍速',
          subtitle: '${_latestValue?.playbackSpeed}x',
          trailing: const Icon(LucideIcons.chevronRight, color: Colors.white38, size: 12),
          onTap: () => setState(() => _showSpeedSubMenu = true),
        ),
        _buildSettingItem(
          title: '去广告',
          trailing: Transform.scale(
            scale: 0.7,
            child: ZenSwitch(
              value: widget.isAdBlockingEnabled,
              onChanged: (val) => widget.onAdBlockingToggle?.call(),
            ),
          ),
        ),
        _buildSettingItem(
          title: '跳过片头片尾',
          trailing: Transform.scale(
            scale: 0.7,
            child: ZenSwitch(
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
          subtitle: _localSkipConfig.outroTime > 0 ? '跳过最后 ${_localSkipConfig.outroTime}s' : '未设置',
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
        return Container(
          color: isSelected ? Colors.greenAccent.withValues(alpha: 0.1) : Colors.transparent,
          child: _buildSettingItem(
            title: '${speed}x',
            textColor: isSelected ? Colors.greenAccent : Colors.white,
            trailing: isSelected ? const Icon(LucideIcons.check, color: Colors.greenAccent, size: 14) : null,
            onTap: () {
              _videoPlayerController?.setPlaybackSpeed(speed);
              setState(() => _showSpeedSubMenu = false);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSettingItem({required String title, String? subtitle, Widget? trailing, VoidCallback? onTap, Color? textColor}) {
    return ListTile(
      title: Text(title, style: TextStyle(color: textColor ?? Colors.white, fontSize: 12)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 9)) : null,
      trailing: trailing,
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final isFullScreen = _chewieController?.isFullScreen ?? false;
    if (!isFullScreen) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: _displayToggles ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        height: _barHeight + 40,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (_chewieController?.isFullScreen ?? false) {
                  _chewieController?.exitFullScreen();
                  // 仅在移动端作为备选方案执行 maybePop
                  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted && Navigator.of(context).canPop()) {
                        Navigator.of(context).maybePop();
                      }
                    });
                  }
                } else {
                  Navigator.of(context).maybePop();
                }
              },
              child: _buildIconBtn(LucideIcons.chevronLeft, () {
                if (_chewieController?.isFullScreen ?? false) {
                  _chewieController?.exitFullScreen();
                } else {
                  Navigator.of(context).maybePop();
                }
              }, size: 28),
            ),
          ],
        ),
      ),
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
                if (!_isLocked) ...[
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
                    if (_chewieController?.isFullScreen ?? false) {
                      _chewieController?.exitFullScreen();
                      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (context.mounted && Navigator.of(context).canPop()) {
                            Navigator.of(context).maybePop();
                          }
                        });
                      }
                    } else {
                      _chewieController?.enterFullScreen();
                    }
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap, {double size = 18}) {
    return _HoverableIcon(icon: icon, onTap: onTap, size: size);
  }

  Widget _buildVolumeButton(BuildContext context) {
    final volume = _videoPlayerController?.value.volume ?? 1.0;
    IconData iconData = LucideIcons.volume2;
    if (volume == 0) {
      iconData = LucideIcons.volumeX;
    } else if (volume < 0.5) {
      iconData = LucideIcons.volume1;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _showVolumeSlider = true),
      onExit: (_) => setState(() => _showVolumeSlider = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HoverableIcon(
            icon: iconData,
            onTap: () {
              if (volume > 0) {
                _lastVolume = volume;
                _videoPlayerController?.setVolume(0.0);
              } else {
                _videoPlayerController?.setVolume(_lastVolume);
              }
              _cancelAndRestartTimer();
            },
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _showVolumeSlider ? 100 : 0,
            height: 30,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: 100,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: volume,
                    onChanged: (val) {
                      _videoPlayerController?.setVolume(val);
                      if (val > 0) {
                        _lastVolume = val;
                        widget.onVolumeChanged?.call(val);
                      }
                      _cancelAndRestartTimer();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
            onChanged: _isLocked ? null : (value) {
              _videoPlayerController!.seekTo(Duration(milliseconds: value.toInt()));
            },
            onChangeStart: _isLocked ? null : (_) => _hideTimer?.cancel(),
            onChangeEnd: _isLocked ? null : (_) => _cancelAndRestartTimer(),
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
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
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
