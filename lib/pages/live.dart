import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/live_service.dart';
import '../services/config_service.dart';
import '../models/live.dart';
import '../widgets/zen_ui.dart';
import '../widgets/video_player.dart';

class LivePage extends ConsumerStatefulWidget {
  const LivePage({super.key});

  @override
  ConsumerState<LivePage> createState() => _LivePageState();
}

class _LivePageState extends ConsumerState<LivePage> {
  List<LiveSource> _sources = [];
  LiveSource? _selectedSource;
  List<LiveChannel> _channels = [];
  LiveChannel? _currentChannel;
  bool _isLoading = false;
  final GlobalKey _playerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  void _loadSources() async {
    final configService = ref.read(configServiceProvider);
    final sources = await configService.getLiveSources();
    if (sources.isNotEmpty && mounted) {
      setState(() {
        _sources = sources;
        _selectedSource = sources.first;
      });
      _loadChannels(sources.first);
    }
  }

  void _loadChannels(LiveSource source) async {
    setState(() => _isLoading = true);
    final service = ref.read(liveServiceProvider);
    final channels = await service.fetchChannels(source.url);
    if (mounted) {
      setState(() {
        _channels = channels;
        _isLoading = false;
        _selectedSource = source;
        // 默认播放第一个频道
        if (channels.isNotEmpty && _currentChannel == null) {
          _currentChannel = channels.first;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPC = screenWidth > 960;

    return ZenScaffold(
      body: isPC ? _buildPCLayout(theme) : _buildMobileLayout(theme),
    );
  }

  Widget _buildPCLayout(ThemeData theme) {
    return Row(
      children: [
        // 左侧播放区域
        Expanded(
          flex: 7,
          child: Container(
            color: Colors.black,
            child: Column(
              children: [
                _buildHeader(theme, true),
                Expanded(
                  child: Center(
                    child: _buildPlayer(),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 右侧列表区域
        Container(
          width: 350,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(left: BorderSide(color: theme.dividerColor)),
          ),
          child: _buildChannelList(theme),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme) {
    return Column(
      children: [
        // 上方播放器
        Container(
          color: Colors.black,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildPlayer(),
          ),
        ),
        // 下方标题和列表
        Expanded(
          child: Column(
            children: [
              _buildHeader(theme, false),
              Expanded(child: _buildChannelList(theme)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, bool isPC) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (!isPC)
            IconButton(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: () => Navigator.pop(context),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentChannel?.name ?? '电视直播',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _selectedSource?.name ?? '未选择源',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary),
                ),
              ],
            ),
          ),
          if (_sources.length > 1)
            PopupMenuButton<LiveSource>(
              icon: const Icon(LucideIcons.listVideo),
              onSelected: _loadChannels,
              itemBuilder: (context) => _sources.map((s) => PopupMenuItem(
                value: s,
                child: Text(s.name),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    if (_currentChannel == null) {
      return const Center(child: Text('请选择频道', style: TextStyle(color: Colors.white54)));
    }

    return EchoVideoPlayer(
      key: ValueKey(_currentChannel!.url), // 频道切换时强制重建播放器
      url: _currentChannel!.url,
      title: _currentChannel!.name,
      isLive: true,
      referer: _currentChannel!.url.startsWith('http') ? Uri.parse(_currentChannel!.url).origin : '',
    );
  }

  Widget _buildChannelList(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_channels.isEmpty) {
      return const Center(child: Text('暂无频道'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _channels.length,
      itemBuilder: (context, index) {
        final channel = _channels[index];
        final isSelected = _currentChannel == channel;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => setState(() => _currentChannel = channel),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.3) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  if (channel.logo != null && channel.logo!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        channel.logo!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(LucideIcons.tv, size: 20, color: theme.colorScheme.secondary),
                      ),
                    )
                  else
                    Icon(LucideIcons.tv, size: 20, color: theme.colorScheme.secondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (channel.group != null)
                          Text(
                            channel.group!,
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.secondary.withValues(alpha: 0.6)),
                          ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(LucideIcons.play, size: 14, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}