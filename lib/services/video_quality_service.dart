import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
    sendTimeout: const Duration(seconds: 4),
  ));

  /// 检测视频质量（分辨率、速度、延迟）
  Future<VideoQualityInfo> detectQuality(String videoUrl) async {
    try {
      // 1. 测量网络延迟
      final pingTime = await _measurePingTime(videoUrl);

      // 2. 如果是 M3U8 文件，解析并测速
      if (videoUrl.toLowerCase().contains('.m3u8')) {
        return await _detectM3u8Quality(videoUrl, pingTime);
      }

      // 3. 如果是直链视频，直接测速
      return await _detectDirectVideoQuality(videoUrl, pingTime);
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
      return 9999; // 失败返回最大延迟
    }
  }

  /// 检测 M3U8 视频质量
  Future<VideoQualityInfo> _detectM3u8Quality(String m3u8Url, int pingTime) async {
    try {
      // 1. 下载 M3U8 文件
      final response = await _dio.get(m3u8Url);
      final m3u8Content = response.data.toString();

      // 2. 解析分辨率信息
      String quality = _parseM3u8Resolution(m3u8Content);

      // 3. 提取第一个 TS 片段 URL
      final tsUrl = _extractFirstTsUrl(m3u8Content, m3u8Url);
      if (tsUrl == null) {
        return VideoQualityInfo(
          quality: quality,
          loadSpeed: '未知',
          pingTime: pingTime,
        );
      }

      // 4. 测量 TS 片段下载速度
      final loadSpeed = await _measureDownloadSpeed(tsUrl);

      return VideoQualityInfo(
        quality: quality,
        loadSpeed: loadSpeed,
        pingTime: pingTime,
      );
    } catch (e) {
      return VideoQualityInfo.error();
    }
  }

  /// 检测直链视频质量
  Future<VideoQualityInfo> _detectDirectVideoQuality(String videoUrl, int pingTime) async {
    try {
      // 测量下载速度
      final loadSpeed = await _measureDownloadSpeed(videoUrl, maxBytes: 512 * 1024);

      return VideoQualityInfo(
        quality: '未知', // 直链无法获取分辨率
        loadSpeed: loadSpeed,
        pingTime: pingTime,
      );
    } catch (e) {
      return VideoQualityInfo.error();
    }
  }

  /// 解析 M3U8 文件中的分辨率信息
  String _parseM3u8Resolution(String m3u8Content) {
    // 查找 RESOLUTION 标签
    final resolutionMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(m3u8Content);
    if (resolutionMatch != null) {
      final width = int.parse(resolutionMatch.group(1)!);
      return _getQualityFromWidth(width);
    }

    // 查找 BANDWIDTH 标签（备用方案）
    final bandwidthMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(m3u8Content);
    if (bandwidthMatch != null) {
      final bandwidth = int.parse(bandwidthMatch.group(1)!);
      return _getQualityFromBandwidth(bandwidth);
    }

    return '未知';
  }

  /// 根据宽度判断分辨率
  String _getQualityFromWidth(int width) {
    if (width >= 3840) return '4K';
    if (width >= 2560) return '2K';
    if (width >= 1920) return '1080p';
    if (width >= 1280) return '720p';
    if (width >= 854) return '480p';
    return 'SD';
  }

  /// 根据带宽判断分辨率（粗略估计）
  String _getQualityFromBandwidth(int bandwidth) {
    if (bandwidth >= 8000000) return '1080p';
    if (bandwidth >= 5000000) return '720p';
    if (bandwidth >= 2000000) return '480p';
    return 'SD';
  }

  /// 提取 M3U8 中的第一个 TS 片段 URL
  String? _extractFirstTsUrl(String m3u8Content, String baseUrl) {
    final lines = m3u8Content.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty && !line.startsWith('#')) {
        // 如果是相对路径，转换为绝对路径
        if (!line.startsWith('http')) {
          final baseUri = Uri.parse(baseUrl);
          final tsUri = baseUri.resolve(line);
          return tsUri.toString();
        }
        return line;
      }
    }
    return null;
  }

  /// 测量下载速度
  Future<String> _measureDownloadSpeed(String url, {int maxBytes = 256 * 1024}) async {
    try {
      final startTime = DateTime.now();
      int downloadedBytes = 0;

      await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
        ),
        onReceiveProgress: (received, total) {
          downloadedBytes = received;
        },
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('Download timeout');
        },
      );

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds / 1000.0;

      if (duration <= 0) {
        return '未知';
      }

      // 计算速度（KB/s）
      final speedKBps = (downloadedBytes / 1024) / duration;

      // 格式化为 KB/s 或 MB/s
      if (speedKBps >= 1024) {
        return '${(speedKBps / 1024).toStringAsFixed(1)} MB/s';
      } else {
        return '${speedKBps.toStringAsFixed(1)} KB/s';
      }
    } catch (e) {
      return '未知';
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
}
