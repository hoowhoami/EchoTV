import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/edit_dialog.dart';
import '../widgets/zen_ui.dart';

class UpdateService {
  static const String githubRepo = 'hoowhoami/EchoTV';
  static const String releaseUrl = 'https://github.com/$githubRepo/releases/latest';
  static const String apiUrl = 'https://api.github.com/repos/$githubRepo/releases/latest';

  /// 检查更新
  static Future<void> checkUpdate(BuildContext context, {bool showNoUpdate = false}) async {
    try {
      final dio = Dio();
      // 设置不抛出 404 异常，以便手动处理
      final response = await dio.get(
        apiUrl,
        options: Options(validateStatus: (status) => status! < 500),
      );
      
      if (response.statusCode == 200) {
        final latestVersion = response.data['tag_name']?.toString().replaceAll('v', '') ?? '';
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_hasNewVersion(currentVersion, latestVersion)) {
          if (!context.mounted) return;
          _showUpdateDialog(context, latestVersion, response.data['body'] ?? '发现新版本，建议立即更新。');
        } else if (showNoUpdate) {
          if (!context.mounted) return;
          _showSnackBar(context, '当前已是最新版本');
        }
      } else if (response.statusCode == 404) {
        if (showNoUpdate && context.mounted) {
          _showSnackBar(context, '暂无可用更新 (尚未发布 Release)');
        }
      }
    } catch (e) {
      if (showNoUpdate && context.mounted) {
        _showSnackBar(context, '检查更新失败: 请检查网络连接');
      }
    }
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 版本比对逻辑
  static bool _hasNewVersion(String current, String latest) {
    if (latest.isEmpty) return false;
    List<int> currParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> lateParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    for (var i = 0; i < 3; i++) {
      int c = i < currParts.length ? currParts[i] : 0;
      int l = i < lateParts.length ? lateParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// 弹出更新对话框
  static void _showUpdateDialog(BuildContext context, String version, String changelog) {
    showDialog(
      context: context,
      builder: (context) => EditDialog(
        title: Text('发现新版本 v$version'),
        width: 400,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('更新内容：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(changelog, style: const TextStyle(fontSize: 13, height: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('稍后再说', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
          ),
          ZenButton(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            borderRadius: 12,
                        onPressed: () async {
                          final url = Uri.parse(releaseUrl);
                          try {
                            final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
                            if (!launched && context.mounted) {
                              _showSnackBar(context, '无法打开下载链接，请手动前往浏览器访问');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              _showSnackBar(context, '无法打开下载链接: $e');
                            }
                          }
                        },            child: const Text('立即前往下载', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
