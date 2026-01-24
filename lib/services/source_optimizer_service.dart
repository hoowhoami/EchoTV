import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/site.dart';
import 'video_quality_service.dart';

final sourceOptimizerServiceProvider = Provider((ref) {
  return SourceOptimizerService(ref.read(videoQualityServiceProvider));
});

/// 播放源优选结果
class SourceOptimizationResult {
  final VideoDetail bestSource;
  final Map<String, VideoQualityInfo> qualityInfoMap;
  final Map<String, double> scoreMap;

  SourceOptimizationResult({
    required this.bestSource,
    required this.qualityInfoMap,
    required this.scoreMap,
  });
}

class SourceOptimizerService {
  final VideoQualityService _qualityService;

  SourceOptimizerService(this._qualityService);

  /// 从多个播放源中选择最佳源
  Future<SourceOptimizationResult> selectBestSource(
    List<VideoDetail> sources, {
    Map<String, VideoQualityInfo>? cachedQualityInfo,
  }) async {
    if (sources.isEmpty) {
      throw Exception('没有可用的播放源');
    }

    if (sources.length == 1) {
      // 只有一个源，直接返回
      final source = sources.first;
      final key = _getSourceKey(source);
      final qualityInfo = cachedQualityInfo?[key] ??
                          await _detectSourceQuality(source);

      return SourceOptimizationResult(
        bestSource: source,
        qualityInfoMap: {key: qualityInfo},
        scoreMap: {key: 100.0},
      );
    }

    // 分批并发测速（避免过多并发请求）
    final batchSize = (sources.length / 2).ceil();
    final allResults = <_SourceTestResult>[];

    for (int start = 0; start < sources.length; start += batchSize) {
      final batchSources = sources.skip(start).take(batchSize).toList();

      final batchResults = await Future.wait(
        batchSources.map((source) async {
          try {
            final key = _getSourceKey(source);

            // 优先使用缓存的质量信息
            final qualityInfo = cachedQualityInfo?[key] ??
                                await _detectSourceQuality(source);

            return _SourceTestResult(
              source: source,
              qualityInfo: qualityInfo,
            );
          } catch (e) {
            return _SourceTestResult(
              source: source,
              qualityInfo: VideoQualityInfo.error(),
            );
          }
        }),
      );

      allResults.addAll(batchResults);
    }

    // 过滤掉检测失败的源
    final successfulResults = allResults.where((r) => !r.qualityInfo.hasError).toList();

    if (successfulResults.isEmpty) {
      // 所有源都失败了，返回第一个
      final source = sources.first;
      final key = _getSourceKey(source);
      return SourceOptimizationResult(
        bestSource: source,
        qualityInfoMap: {key: VideoQualityInfo.error()},
        scoreMap: {key: 0.0},
      );
    }

    // 计算统计数据（用于归一化）
    final speeds = successfulResults.map((r) => r.qualityInfo.speedKBps).toList();
    final pings = successfulResults.map((r) => r.qualityInfo.pingTime).toList();

    final maxSpeed = speeds.reduce((a, b) => a > b ? a : b);
    final minPing = pings.reduce((a, b) => a < b ? a : b);
    final maxPing = pings.reduce((a, b) => a > b ? a : b);

    // 计算每个源的综合评分
    final resultsWithScore = successfulResults.map((result) {
      final score = _calculateSourceScore(
        result.qualityInfo,
        maxSpeed,
        minPing,
        maxPing,
      );
      return _ScoredSourceResult(
        source: result.source,
        qualityInfo: result.qualityInfo,
        score: score,
      );
    }).toList();

    // 按评分降序排列
    resultsWithScore.sort((a, b) => b.score.compareTo(a.score));

    // 构建结果
    final qualityInfoMap = <String, VideoQualityInfo>{};
    final scoreMap = <String, double>{};

    for (var result in resultsWithScore) {
      final key = _getSourceKey(result.source);
      qualityInfoMap[key] = result.qualityInfo;
      scoreMap[key] = result.score;
    }

    return SourceOptimizationResult(
      bestSource: resultsWithScore.first.source,
      qualityInfoMap: qualityInfoMap,
      scoreMap: scoreMap,
    );
  }

  /// 检测单个播放源的质量
  Future<VideoQualityInfo> _detectSourceQuality(VideoDetail source) async {
    // 获取第二集或第一集的 URL 进行测速
    final playGroup = source.playGroups.first;
    final testUrl = playGroup.urls.length > 1
        ? playGroup.urls[1]
        : playGroup.urls[0];

    return await _qualityService.detectQuality(testUrl);
  }

  /// 计算播放源的综合评分
  /// 权重分配：40% 分辨率 + 40% 速度 + 20% 延迟
  double _calculateSourceScore(
    VideoQualityInfo qualityInfo,
    double maxSpeed,
    int minPing,
    int maxPing,
  ) {
    double score = 0.0;

    // 1. 分辨率评分（40% 权重）
    final qualityScore = _getQualityScore(qualityInfo.quality);
    score += qualityScore * 0.4;

    // 2. 下载速度评分（40% 权重）
    if (maxSpeed > 0) {
      final speedScore = (qualityInfo.speedKBps / maxSpeed) * 100;
      score += speedScore.clamp(0, 100) * 0.4;
    }

    // 3. 网络延迟评分（20% 权重）
    if (maxPing > minPing) {
      final pingScore = ((maxPing - qualityInfo.pingTime) / (maxPing - minPing)) * 100;
      score += pingScore.clamp(0, 100) * 0.2;
    } else {
      // 所有源延迟相同，给满分
      score += 100 * 0.2;
    }

    return (score * 100).round() / 100.0; // 保留两位小数
  }

  /// 获取分辨率对应的评分
  double _getQualityScore(String quality) {
    switch (quality) {
      case '4K':
        return 100;
      case '2K':
        return 85;
      case '1080p':
        return 75;
      case '720p':
        return 60;
      case '480p':
        return 40;
      case 'SD':
        return 20;
      default:
        return 0;
    }
  }

  /// 生成播放源的唯一标识
  String _getSourceKey(VideoDetail source) {
    return '${source.source}-${source.id}';
  }
}

/// 播放源测试结果（内部使用）
class _SourceTestResult {
  final VideoDetail source;
  final VideoQualityInfo qualityInfo;

  _SourceTestResult({
    required this.source,
    required this.qualityInfo,
  });
}

/// 带评分的播放源结果（内部使用）
class _ScoredSourceResult {
  final VideoDetail source;
  final VideoQualityInfo qualityInfo;
  final double score;

  _ScoredSourceResult({
    required this.source,
    required this.qualityInfo,
    required this.score,
  });
}
