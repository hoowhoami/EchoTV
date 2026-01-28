import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/config_service.dart';

/// 通用封面图片组件
/// - 如果是豆瓣地址，自动处理代理
/// - 否则直接显示
class CoverImage extends ConsumerWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double aspectRatio;

  const CoverImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.aspectRatio = 2 / 3, // 默认 2:3 海报比例
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 检查是否为豆瓣地址
    final isDoubanUrl = _isDoubanUrl(imageUrl);

    if (isDoubanUrl) {
      // 豆瓣地址：使用代理
      return FutureBuilder<String>(
        future: ref.read(configServiceProvider).processImageUrl(imageUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // 显示占位符直到 URL 处理完成
            return AspectRatio(
              aspectRatio: aspectRatio,
              child: placeholder != null
                  ? placeholder!
                  : Container(color: Colors.grey[200]),
            );
          }

          final processedUrl = snapshot.data ?? imageUrl;
          return AspectRatio(
            aspectRatio: aspectRatio,
            child: _buildImage(processedUrl),
          );
        },
      );
    } else {
      // 非豆瓣地址：直接显示
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: _buildImage(imageUrl),
      );
    }
  }

  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: placeholder != null
          ? (context, url) => placeholder!
          : (context, url) => Container(color: Colors.grey[200]),
      errorWidget: errorWidget != null
          ? (context, url, error) => errorWidget!
          : (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.error, color: Colors.grey),
                ),
              ),
    );
  }

  /// 判断是否为豆瓣图片地址
  bool _isDoubanUrl(String url) {
    return url.isNotEmpty && url.contains('doubanio.com');
  }
}
