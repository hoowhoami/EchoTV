import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/config_service.dart';
import '../services/subscription_service.dart';
import '../providers/settings_provider.dart';
import '../models/site.dart';
import '../models/live.dart';
import '../widgets/zen_ui.dart';
import 'source_manage.dart';
import 'category_manage.dart';
import 'live_manage.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _doubanProxy = 'tencent-cmlius';
  String _doubanImageProxy = 'cmliussss-cdn-tencent';
  String _siteName = 'EchoTV';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final service = ref.read(configServiceProvider);
    final doubanProxy = await service.getDoubanProxyType();
    final doubanImageProxy = await service.getDoubanImageProxyType();
    final siteName = await service.getSiteName();

    if (mounted) {
      setState(() {
        _doubanProxy = doubanProxy;
        _doubanImageProxy = doubanImageProxy;
        _siteName = siteName;
      });
    }
  }

  void _showJsonImport() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('导入 JSON 配置'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: '粘贴符合 LunaTV 格式的 JSON...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              try {
                final json = jsonDecode(controller.text);
                await SubscriptionService(ref.read(configServiceProvider)).importFromJson(json);
                _loadSettings();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('解析失败: $e')));
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void _showRemoteSync() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('同步远程订阅'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '输入订阅 URL (JSON)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              try {
                await SubscriptionService(ref.read(configServiceProvider)).syncFromUrl(controller.text);
                _loadSettings();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('同步失败: $e')));
              }
            },
            child: const Text('同步'),
          ),
        ],
      ),
    );
  }

  void _exportConfig() async {
    final config = await ref.read(configServiceProvider).exportAll();
    await Clipboard.setData(ClipboardData(text: config));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配置已复制到剪贴板')));
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 24),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }

  Widget _buildSettingCard({required List<Widget> children}) {
    return ZenGlassContainer(
      borderRadius: 24,
      blur: 20,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
          title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          trailing: trailing ?? const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 56,
            endIndent: 16,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: Text(
                '设置',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle('外观与偏好'),
                _buildSettingCard(children: [
                  _buildSettingItem(
                    icon: Icons.palette_outlined,
                    title: '主题模式',
                    trailing: DropdownButton<ThemeMode>(
                      value: ref.watch(themeModelProvider),
                      underline: const SizedBox(),
                      dropdownColor: Theme.of(context).cardColor,
                      iconEnabledColor: Theme.of(context).colorScheme.primary,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (mode) async {
                        if (mode != null) {
                          await ref.read(themeModelProvider.notifier).setThemeMode(mode);
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
                        DropdownMenuItem(value: ThemeMode.light, child: Text('明亮')),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text('深邃')),
                      ],
                    ),
                  ),
                  _buildSettingItem(
                    icon: Icons.language_outlined,
                    title: '豆瓣 API 代理',
                    trailing: DropdownButton<String>(
                      value: _doubanProxy,
                      underline: const SizedBox(),
                      dropdownColor: Theme.of(context).cardColor,
                      iconEnabledColor: Theme.of(context).colorScheme.primary,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (type) async {
                        if (type != null) {
                          await ref.read(configServiceProvider).setDoubanProxyType(type);
                          _loadSettings();
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'tencent-cmlius', child: Text('腾讯云镜像')),
                        DropdownMenuItem(value: 'aliyun-cmlius', child: Text('阿里云镜像')),
                        DropdownMenuItem(value: 'none', child: Text('直连')),
                      ],
                    ),
                  ),
                  _buildSettingItem(
                    icon: Icons.image_outlined,
                    title: '豆瓣图片代理',
                    showDivider: false,
                    trailing: DropdownButton<String>(
                      value: _doubanImageProxy,
                      underline: const SizedBox(),
                      dropdownColor: Theme.of(context).cardColor,
                      iconEnabledColor: Theme.of(context).colorScheme.primary,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (type) async {
                        if (type != null) {
                          await ref.read(configServiceProvider).setDoubanImageProxyType(type);
                          _loadSettings();
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'cmliussss-cdn-tencent', child: Text('腾讯云 CDN')),
                        DropdownMenuItem(value: 'cmliussss-cdn-ali', child: Text('阿里云 CDN')),
                        DropdownMenuItem(value: 'img3', child: Text('豆瓣官方 CDN')),
                        DropdownMenuItem(value: 'direct', child: Text('直连')),
                      ],
                    ),
                  ),
                ]),

                _buildSectionTitle('数据源管理'),
                _buildSettingCard(children: [
                  _buildSettingItem(
                    icon: Icons.movie_filter_outlined,
                    title: '视频 CMS 站点',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourceManagePage())),
                  ),
                  _buildSettingItem(
                    icon: Icons.category_outlined,
                    title: '自定义分类映射',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagePage())),
                  ),
                  _buildSettingItem(
                    icon: Icons.live_tv_outlined,
                    title: '直播 M3U 订阅',
                    showDivider: false,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveManagePage())),
                  ),
                ]),

                _buildSectionTitle('配置同步'),
                _buildSettingCard(children: [
                  _buildSettingItem(
                    icon: Icons.cloud_download_outlined,
                    title: '同步远程配置',
                    onTap: _showRemoteSync,
                  ),
                  _buildSettingItem(
                    icon: Icons.code_rounded,
                    title: '从 JSON 导入',
                    onTap: _showJsonImport,
                  ),
                  _buildSettingItem(
                    icon: Icons.ios_share_outlined,
                    title: '导出完整配置',
                    showDivider: false,
                    onTap: _exportConfig,
                  ),
                ]),

                _buildSectionTitle('高级设置'),
                _buildSettingCard(children: [
                  _buildSettingItem(
                    icon: Icons.cleaning_services_outlined,
                    title: '清除缓存',
                    trailing: const Text('12.5 MB', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    onTap: () {},
                  ),
                  _buildSettingItem(
                    icon: Icons.info_outline,
                    title: '关于 EchoTV',
                    showDivider: false,
                    trailing: const Text('v1.0.0', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                ]),
                
                const SizedBox(height: 120),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}