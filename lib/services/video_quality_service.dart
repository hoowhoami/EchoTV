import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

final videoQualityServiceProvider = Provider((ref) => VideoQualityService());

/// 视频质量信息
class VideoQualityInfo {
  final String quality; // 分辨率：4K, 2K, 1080p, 720p, 480p, SD, 未知
  final String loadSpeed; // 下载速度：格式化为 KB/s 或 MB/s
  final int pingTime; // 网络延迟（毫秒）
  final bool hasError; // 是否检测失败

  VideoQualityInfo({
    required this.quality,
    required this.loadSpeed,
    required this.pingTime,
    this.hasError = false,
  });

  factory VideoQualityInfo.error() {
    return VideoQualityInfo(
      quality: '错误',
      loadSpeed: '未知',
      pingTime: 9999,
      hasError: true,
    );
  }

  /// 获取速度的数值（KB/s）
  double get speedKBps {
    try {
      final match = RegExp(r'([\d.]+)\s*(KB|MB)/s').firstMatch(loadSpeed);
      if (match != null) {
        final value = double.parse(match.group(1)!);
        final unit = match.group(2);
        return unit == 'MB' ? value * 1024 : value;
      }
    } catch (e) {
      // ignore
    }
    return 0;
  }
}

class VideoQualityService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
    sendTimeout: const Duration(seconds: 5),
  ));

  /// 检测视频质量（分辨率、速度、延迟）
  Future<VideoQualityInfo> detectQuality(String videoUrl) async {
    try {
      // 并发执行 Ping 和 内容质量检测
      final results = await Future.wait([
        _measurePingTime(videoUrl),
        _detectVideoContentQuality(videoUrl),
      ]);

      final pingTime = results[0] as int;
      final contentInfo = results[1] as Map<String, dynamic>;

      return VideoQualityInfo(
        quality: contentInfo['quality'] ?? '未知',
        loadSpeed: contentInfo['loadSpeed'] ?? '未知',
        pingTime: pingTime,
      );
    } catch (e) {
      return VideoQualityInfo.error();
    }
  }

  /// 测量网络延迟（Ping 时间）
  Future<int> _measurePingTime(String url) async {
    try {
      final startTime = DateTime.now();
      await _dio.head(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final endTime = DateTime.now();
      return endTime.difference(startTime).inMilliseconds;
    } catch (e) {
      return 9999;
    }
  }

  Future<Map<String, dynamic>> _detectVideoContentQuality(String videoUrl) async {
    if (videoUrl.toLowerCase().contains('.m3u8')) {
      return await _detectM3u8Content(videoUrl);
    }
    
    // 直链视频测速
    final speed = await _measureDownloadSpeed(videoUrl, maxBytes: 512 * 1024);
    return {'quality': '未知', 'loadSpeed': speed};
  }

  Future<Map<String, dynamic>> _detectM3u8Content(String m3u8Url) async {
    try {
      final response = await _dio.get(m3u8Url);
      final content = response.data.toString();
      
      // 1. 解析最高分辨率
      String quality = _parseM3u8Resolution(content);
      
      // 2. 处理 Master Playlist (嵌套)
      final subM3u8 = _extractFirstSubM3u8(content, m3u8Url);
      if (subM3u8 != null) {
        final subResult = await _detectM3u8Content(subM3u8);
        if (subResult['quality'] != '未知') quality = subResult['quality'];
        return subResult..['quality'] = quality;
      }

      // 3. 提取 TS 视频流片段并测速
      final tsUrl = _extractFirstTsUrl(content, m3u8Url);
      if (tsUrl == null) return {'quality': quality, 'loadSpeed': '未知'};

      final speed = await _measureDownloadSpeed(tsUrl);
      return {'quality': quality, 'loadSpeed': speed};
    } catch (e) {
      return {'quality': '未知', 'loadSpeed': '未知'};
    }
  }

  /// 解析 M3U8 文件中的最高分辨率
  String _parseM3u8Resolution(String m3u8Content) {
    final matches = RegExp(r'RESOLUTION=(\d+)x(\d+)').allMatches(m3u8Content);
    if (matches.isNotEmpty) {
      int maxWidth = 0;
      for (var match in matches) {
        final width = int.parse(match.group(1)!);
        if (width > maxWidth) maxWidth = width;
      }
      return _getQualityFromWidth(maxWidth);
    }

    final bwMatches = RegExp(r'BANDWIDTH=(\d+)').allMatches(m3u8Content);
    if (bwMatches.isNotEmpty) {
      int maxBw = 0;
      for (var match in bwMatches) {
        final bw = int.parse(match.group(1)!);
        if (bw > maxBw) maxBw = bw;
      }
      return _getQualityFromBandwidth(maxBw);
    }

    return '未知';
  }

  String _getQualityFromWidth(int width) {
    if (width >= 3840) return '4K';
    if (width >= 2560) return '2K';
    if (width >= 1920) return '1080p';
    if (width >= 1280) return '720p';
    if (width >= 854) return '480p';
    return 'SD';
  }

  String _getQualityFromBandwidth(int bandwidth) {
    if (bandwidth >= 8000000) return '1080p';
    if (bandwidth >= 5000000) return '720p';
    if (bandwidth >= 2000000) return '480p';
    return 'SD';
  }

  String? _extractFirstSubM3u8(String content, String baseUrl) {
    final lines = content.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty && !line.startsWith('#') && line.toLowerCase().contains('.m3u8')) {
        return _resolveUrl(baseUrl, line);
      }
    }
    return null;
  }

  String? _extractFirstTsUrl(String content, String baseUrl) {
    final lines = content.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty && !line.startsWith('#')) {
        if (!line.toLowerCase().contains('.m3u8')) {
          return _resolveUrl(baseUrl, line);
        }
      }
    }
    return null;
  }

  String _resolveUrl(String baseUrl, String relativeUrl) {
    if (relativeUrl.startsWith('http')) return relativeUrl;
    final baseUri = Uri.parse(baseUrl);
    return baseUri.resolve(relativeUrl).toString();
  }

  /// 真实流式测速
  Future<String> _measureDownloadSpeed(String url, {int maxBytes = 1024 * 1024}) async {
    final stopwatch = Stopwatch()..start();
    int downloadedBytes = 0;

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
        ),
      );

      final stream = response.data!.stream;
      
      await for (final chunk in stream) {
        downloadedBytes += chunk.length;
        // 测速满 1MB 或超过 3.5 秒则停止
        if (downloadedBytes >= maxBytes || stopwatch.elapsedMilliseconds > 3500) {
          break;
        }
      }
      stopwatch.stop();

      final durationSec = stopwatch.elapsedMilliseconds / 1000.0;
      if (durationSec <= 0 || downloadedBytes <= 0) return '未知';

      final speedKBpsValue = (downloadedBytes / 1024) / durationSec;

      if (speedKBpsValue >= 1024) {
        return '${(speedKBpsValue / 1024).toStringAsFixed(1)} MB/s';
      } else {
        return '${speedKBpsValue.toStringAsFixed(1)} KB/s';
      }
    } catch (e) {
      return '未知';
    } finally {
      stopwatch.stop();
    }
  }
}