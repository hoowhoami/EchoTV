import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/config_service.dart';

/// 通用封面图片组件
/// - 采用静态处理逻辑，避免 FutureBuilder 频繁触发
/// - 内部自动处理豆瓣代理逻辑
class CoverImage extends ConsumerStatefulWidget {
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
    this.aspectRatio = 2 / 3,
  });

  @override
  ConsumerState<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends ConsumerState<CoverImage> {
  String? _processedUrl;
  late bool _isLoading;

  @override
  void initState() {
    super.initState();
    // 第一步：同步判断是否需要代理，如果是豆瓣地址，初始状态即为加载中
    final isDouban = widget.imageUrl.isNotEmpty && widget.imageUrl.contains('doubanio.com');
    _isLoading = isDouban;
    _processUrl();
  }

  @override
  void didUpdateWidget(CoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      final isDouban = widget.imageUrl.isNotEmpty && widget.imageUrl.contains('doubanio.com');
      setState(() {
        _isLoading = isDouban;
        _processedUrl = null;
      });
      _processUrl();
    }
  }

  void _processUrl() async {
    final isDoubanUrl = widget.imageUrl.isNotEmpty && widget.imageUrl.contains('doubanio.com');
    
    if (!isDoubanUrl) {
      if (mounted) {
        setState(() {
          _processedUrl = widget.imageUrl;
          _isLoading = false;
        });
      }
      return;
    }

    // 从 Provider 读取服务进行处理
    final processed = await ref.read(configServiceProvider).processImageUrl(widget.imageUrl);
    
    if (mounted) {
      setState(() {
        _processedUrl = processed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 渲染占位符
    final loadingPlaceholder = AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: widget.placeholder ?? Container(
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.white.withValues(alpha: 0.05) 
            : Colors.black.withValues(alpha: 0.05),
      ),
    );

    if (_processedUrl == null && _isLoading) {
      return loadingPlaceholder;
    }

    final finalUrl = _processedUrl ?? widget.imageUrl;

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: CachedNetworkImage(
        imageUrl: finalUrl,
        fit: widget.fit,
        // 添加 Referer 绕过豆瓣防盗链
        httpHeaders: const {
          'Referer': 'https://movie.douban.com/',
        },
        // 使用 memCache 优化性能
        memCacheHeight: 600, 
        placeholder: (context, url) => loadingPlaceholder,
        errorWidget: (context, url, error) => widget.errorWidget ?? Container(
          color: Colors.black12,
          child: const Center(child: Icon(Icons.broken_image_outlined, size: 24, color: Colors.grey)),
        ),
      ),
    );
  }
}