import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../services/live_service.dart';
import '../services/config_service.dart';
import '../models/live.dart';
import '../widgets/zen_ui.dart';
import 'play.dart';

class LivePage extends ConsumerStatefulWidget {
  const LivePage({Key? key}) : super(key: key);

  @override
  ConsumerState<LivePage> createState() => _LivePageState();
}

class _LivePageState extends ConsumerState<LivePage> {
  List<LiveSource> _sources = [];
  LiveSource? _selectedSource;
  List<LiveChannel> _channels = [];
  bool _isLoading = false;

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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPC = screenWidth > 800;
    final horizontalPadding = isPC ? 48.0 : 24.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            expandedHeight: isPC ? 90 : 80,
            floating: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: EdgeInsets.only(
                left: horizontalPadding, 
                right: horizontalPadding,
                bottom: 12,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '电视直播',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: isPC ? 15 : 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '来自 M3U 订阅的直播源',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                      color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (_sources.length > 1)
                PopupMenuButton<LiveSource>(
                  icon: Icon(Icons.playlist_play, color: theme.colorScheme.primary),
                  onSelected: _loadChannels,
                  itemBuilder: (context) => _sources.map((s) => PopupMenuItem(
                    value: s,
                    child: Text(s.name),
                  )).toList(),
                ),
              if (!isPC) ...[
                IconButton(
                  onPressed: () => context.go('/search'),
                  icon: const Icon(LucideIcons.search, size: 20),
                ),
                IconButton(
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(LucideIcons.settings, size: 20),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_channels.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(child: Text('未发现频道，请检查源配置')),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final channel = _channels[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          if (context.mounted) {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => PlayPage(videoUrl: channel.url, title: channel.name),
                            ));
                          }
                        },
                        child: ZenGlassContainer(
                          borderRadius: 20,
                          blur: 20,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                if (channel.logo != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(channel.logo!, width: 40, height: 40, fit: BoxFit.contain, errorBuilder: (_,__,___) => Icon(Icons.tv, color: Theme.of(context).colorScheme.secondary)),
                                  )
                                else
                                  Icon(Icons.tv, color: Theme.of(context).colorScheme.secondary, size: 32),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(channel.name, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (channel.group != null)
                                        Text(channel.group!, style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.play_arrow_rounded, color: Theme.of(context).colorScheme.secondary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _channels.length,
                ),
              ),
            ),
            
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}