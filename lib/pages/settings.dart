import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/config_service.dart';
import '../services/subscription_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/zen_ui.dart';
import '../widgets/edit_dialog.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final service = ref.read(configServiceProvider);
    final doubanProxy = await service.getDoubanProxyType();
    final doubanImageProxy = await service.getDoubanImageProxyType();

    if (mounted) {
      setState(() {
        _doubanProxy = doubanProxy;
        _doubanImageProxy = doubanImageProxy;
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
          // 1. 统一风格的头部
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
                    '设置',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: isPC ? 15 : 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '偏好设置与系统同步',
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
          ),

          // 2. 设置主体内容
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle('外观与偏好'),
                _buildSettingGroup([
                  _buildSelectionItem(
                    icon: LucideIcons.palette,
                    title: '主题模式',
                    value: _getThemeModeLabel(ref.watch(themeModelProvider)),
                    onTap: () => _showThemePicker(),
                  ),
                  _buildSelectionItem(
                    icon: LucideIcons.globe,
                    title: '豆瓣 API 代理',
                    value: _getProxyLabel(_doubanProxy),
                    onTap: () => _showProxyPicker(),
                  ),
                  _buildSelectionItem(
                    icon: LucideIcons.image,
                    title: '豆瓣图片代理',
                    value: _getImageProxyLabel(_doubanImageProxy),
                    showDivider: false,
                    onTap: () => _showImageProxyPicker(),
                  ),
                ]),

                _buildSectionTitle('数据源管理'),
                _buildSettingGroup([
                  _buildNavigationItem(
                    icon: LucideIcons.database,
                    title: '视频 CMS 站点',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourceManagePage())),
                  ),
                  _buildNavigationItem(
                    icon: LucideIcons.layers,
                    title: '自定义分类映射',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagePage())),
                  ),
                  _buildNavigationItem(
                    icon: LucideIcons.tv,
                    title: '直播 M3U 订阅',
                    showDivider: false,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveManagePage())),
                  ),
                ]),

                _buildSectionTitle('配置同步'),
                _buildSettingGroup([
                  _buildActionItem(
                    icon: LucideIcons.refreshCw,
                    title: '同步远程配置',
                    onTap: _showRemoteSync,
                  ),
                  _buildActionItem(
                    icon: LucideIcons.fileJson,
                    title: '从 JSON 导入',
                    onTap: _showJsonImport,
                  ),
                  _buildActionItem(
                    icon: LucideIcons.share,
                    title: '导出完整配置',
                    showDivider: false,
                    onTap: _exportConfig,
                  ),
                ]),

                _buildSectionTitle('高级设置'),
                _buildSettingGroup([
                  _buildInfoItem(
                    icon: LucideIcons.trash2,
                    title: '清除缓存',
                    trailing: '12.5 MB',
                  ),
                  _buildInfoItem(
                    icon: LucideIcons.info,
                    title: '关于 EchoTV',
                    trailing: 'v1.0.0',
                    showDivider: false,
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

  // --- 组件构建方法 ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 32, 0, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildSettingGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildBaseItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
    bool showDivider = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
            if (showDivider)
              Divider(
                height: 1,
                indent: 52,
                endIndent: 0,
                color: Theme.of(context).dividerColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionItem({required IconData icon, required String title, required String value, required VoidCallback onTap, bool showDivider = true}) {
    return _buildBaseItem(
      icon: icon,
      title: title,
      onTap: onTap,
      showDivider: showDivider,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 13)),
          const SizedBox(width: 4),
          Icon(LucideIcons.chevronRight, size: 14, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _buildNavigationItem({required IconData icon, required String title, required VoidCallback onTap, bool showDivider = true}) {
    return _buildBaseItem(
      icon: icon,
      title: title,
      onTap: onTap,
      showDivider: showDivider,
      trailing: Icon(LucideIcons.chevronRight, size: 16, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
    );
  }

  Widget _buildActionItem({required IconData icon, required String title, required VoidCallback onTap, bool showDivider = true}) {
    return _buildBaseItem(icon: icon, title: title, onTap: onTap, showDivider: showDivider);
  }

  Widget _buildInfoItem({required IconData icon, required String title, required String trailing, bool showDivider = true}) {
    return _buildBaseItem(
      icon: icon,
      title: title,
      showDivider: showDivider,
      trailing: Text(trailing, style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 13)),
    );
  }

  // --- 数据转换与弹窗 ---

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system: return '跟随系统';
      case ThemeMode.light: return '浅色';
      case ThemeMode.dark: return '深色';
    }
  }

  String _getProxyLabel(String val) {
    if (val == 'tencent-cmlius') return '腾讯云镜像';
    if (val == 'aliyun-cmlius') return '阿里云镜像';
    return '直连';
  }

  String _getImageProxyLabel(String val) {
    if (val == 'cmliussss-cdn-tencent') return '腾讯云 CDN';
    if (val == 'cmliussss-cdn-ali') return '阿里云 CDN';
    if (val == 'img3') return '豆瓣官方';
    return '直连';
  }

  void _showThemePicker() {
    _showSimplePicker('选择主题模式', {
      ThemeMode.system: '跟随系统',
      ThemeMode.light: '浅色',
      ThemeMode.dark: '深色',
    }, ref.read(themeModelProvider), (mode) {
      ref.read(themeModelProvider.notifier).setThemeMode(mode as ThemeMode);
    });
  }

  void _showProxyPicker() {
    _showSimplePicker('选择 API 代理', {
      'tencent-cmlius': '腾讯云镜像',
      'aliyun-cmlius': '阿里云镜像',
      'none': '直连',
    }, _doubanProxy, (val) async {
      await ref.read(configServiceProvider).setDoubanProxyType(val as String);
      _loadSettings();
    });
  }

  void _showImageProxyPicker() {
    _showSimplePicker('选择图片代理', {
      'cmliussss-cdn-tencent': '腾讯云 CDN',
      'cmliussss-cdn-ali': '阿里云 CDN',
      'img3': '豆瓣官方',
      'direct': '直连',
    }, _doubanImageProxy, (val) async {
      await ref.read(configServiceProvider).setDoubanImageProxyType(val as String);
      _loadSettings();
    });
  }

  void _showSimplePicker(String title, Map<dynamic, String> options, dynamic currentVal, Function(dynamic) onSelect) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPC = screenWidth > 800;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxWidth: isPC ? 500 : double.infinity,
        ),
        margin: isPC ? const EdgeInsets.only(bottom: 40) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: isPC ? BorderRadius.circular(28) : const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: isPC ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40)] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPC) 
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options.entries.map((e) {
                    final isSelected = e.key == currentVal;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            onSelect(e.key);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    e.value,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected 
                                          ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white) 
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    LucideIcons.check, 
                                    size: 18, 
                                    color: theme.brightness == Brightness.dark ? Colors.black : Colors.white
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // --- 逻辑操作 (保持原有) ---

  void _showJsonImport() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => EditDialog(
        title: const Text('导入 JSON 配置', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 8,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: '粘贴符合格式的 JSON...',
            filled: true,
            fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: Theme.of(context).colorScheme.secondary))),
          TextButton(
            onPressed: () async {
              try {
                final json = jsonDecode(controller.text);
                await SubscriptionService(ref.read(configServiceProvider)).importFromJson(json);
                _loadSettings();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('解析失败: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
              }
            },
            child: Text('导入', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRemoteSync() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => EditDialog(
        title: const Text('同步远程订阅', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '输入订阅 URL (JSON)',
            filled: true,
            fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: Theme.of(context).colorScheme.secondary))),
          TextButton(
            onPressed: () async {
              try {
                await SubscriptionService(ref.read(configServiceProvider)).syncFromUrl(controller.text);
                _loadSettings();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('同步失败: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
              }
            },
            child: Text('同步', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _exportConfig() async {
    final config = await ref.read(configServiceProvider).exportAll();
    await Clipboard.setData(ClipboardData(text: config));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('配置已复制到剪贴板'), behavior: SnackBarBehavior.floating));
    }
  }
}
