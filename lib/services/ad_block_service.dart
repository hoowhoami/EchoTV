import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

final adBlockServiceProvider = Provider((ref) {
  final service = AdBlockService();
  return service;
});

class AdBlockService {
  HttpServer? _server;
  int? _port;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    },
  ));

  Future<void> init() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      debugPrint('🛡️ AdBlock Proxy Server running on port $_port');
      
      _server!.listen((HttpRequest request) async {
        try {
          if (request.uri.path == '/proxy') {
            await _handleProxyRequest(request);
          } else {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
          }
        } catch (e) {
          debugPrint('❌ Proxy Request Error: $e');
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        }
      }, onError: (e) => debugPrint('⚠️ Server Listen Error: $e'));
    } catch (e) {
      debugPrint('❌ Failed to start AdBlock Server: $e');
    }
  }

  String getProxyUrl(String originalUrl) {
    if (_port == null) return originalUrl;
    final encodedUrl = base64Url.encode(utf8.encode(originalUrl));
    return 'http://127.0.0.1:$_port/proxy?url=$encodedUrl';
  }

  Future<void> _handleProxyRequest(HttpRequest request) async {
    final encodedUrl = request.uri.queryParameters['url'];
    if (encodedUrl == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final String originalUrl = utf8.decode(base64Url.decode(encodedUrl));
    final uri = Uri.parse(originalUrl);
    
    try {
      final response = await _dio.get<String>(
        originalUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final String content = response.data ?? '';
      
      if (content.isEmpty) {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl', charset: 'utf-8');

      if (content.contains('#EXT-X-STREAM-INF')) {
        request.response.write(_proxyMasterPlaylist(content, uri));
      } else if (content.contains('#EXTINF')) {
        request.response.write(_filterAds(content, uri));
      } else {
        request.response.write(content);
      }
    } catch (e) {
      debugPrint('❌ AdBlock Proxy Fetch Error: $e URL: $originalUrl');
      request.response.statusCode = HttpStatus.badGateway;
    } finally {
      await request.response.close();
    }
  }

  String _proxyMasterPlaylist(String content, Uri baseUri) {
    final lines = content.split('\n');
    final result = <String>[];
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) {
        result.add(trimmed);
      } else {
        result.add(getProxyUrl(_getAbsoluteUrl(trimmed, baseUri)));
      }
    }
    return result.join('\n');
  }

  String _filterAds(String content, Uri baseUri) {
    content = content.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (match) {
      final uri = match.group(1)!;
      return 'URI="${_getAbsoluteUrl(uri, baseUri)}"';
    });

    final lines = content.split('\n');
    final adKeywords = [
      'ads', 'union', 'click', 'p6p', 'pop', 'short.mp4', 'advert', 'adv.', 
      'guanggao', 'miaopai', '666216.com', 'v.it608.com', 'ovscic'
    ];
    
    // --- 第一遍扫描：自动探测正片所在的 CDN 域名 ---
    final Map<String, int> hostCounts = {};
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
        try {
          final uri = Uri.parse(_getAbsoluteUrl(trimmed, baseUri));
          hostCounts[uri.host] = (hostCounts[uri.host] ?? 0) + 1;
        } catch (e) {}
      }
    }
    
    // 找出出现次数超过 5% 的域名中，出现次数最多的那个作为“正片域名”
    String? mainVideoHost;
    int maxCount = 0;
    hostCounts.forEach((host, count) {
      if (count > maxCount) {
        maxCount = count;
        mainVideoHost = host;
      }
    });

    // --- 第二遍扫描：执行过滤 ---
    final result = <String>[];
    int segmentCount = 0;
    bool lastWasRemoved = false;
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        segmentCount++;
        final durationMatch = RegExp(r'#EXTINF:(\d+(\.\d+)?)').firstMatch(line);
        final duration = double.tryParse(durationMatch?.group(1) ?? '0') ?? 0;

        int urlIndex = i + 1;
        while (urlIndex < lines.length && lines[urlIndex].trim().startsWith('#')) {
          urlIndex++;
        }

        if (urlIndex < lines.length) {
          final rawUrl = lines[urlIndex].trim();
          final absoluteUrl = _getAbsoluteUrl(rawUrl, baseUri);
          final segmentUri = Uri.parse(absoluteUrl);

          bool isAd = false;

          // 判定逻辑 A: 显式黑名单 (最高优先级)
          if (adKeywords.any((kw) => absoluteUrl.toLowerCase().contains(kw))) {
            isAd = true;
          }
          
          // 判定逻辑 B: 域名/时长组合特征
          // 如果域名既不是主站也不是正片存储站，且时长较短，则判定为广告
          if (segmentUri.host != mainVideoHost && segmentUri.host != baseUri.host && duration < 8.0) {
            isAd = true;
          }

          // 判定逻辑 C: 采集站典型的 Pre-roll 广告 (前 3 片且域名偏移)
          if (segmentCount <= 3 && duration < 4.5 && segmentUri.host != mainVideoHost) {
            isAd = true;
          }

          if (isAd) {
            debugPrint('🚫 AdBlock: Filtered ad segment (${duration}s) -> $absoluteUrl');
            lastWasRemoved = true;
            i = urlIndex;
            continue;
          }
          
          result.add(line);
          for (int j = i + 1; j < urlIndex; j++) {
            result.add(lines[j].trim());
          }
          result.add(absoluteUrl);
          i = urlIndex;
          lastWasRemoved = false;
          continue;
        }
      }

      // 如果当前行是断点标记，且上一片刚被移除，我们需要谨慎处理这个标记
      if (line.startsWith('#EXT-X-DISCONTINUITY')) {
        // 暂存，稍后统一 sanitize
        result.add(line);
      } else if (line.startsWith('#')) {
        result.add(line);
      }
    }

    return _sanitizeDiscontinuity(result).join('\n');
  }

  /// 清理多余的不连续标记，防止播放器因分片移除导致的缓冲抖动
  List<String> _sanitizeDiscontinuity(List<String> lines) {
    final clean = <String>[];
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('#EXT-X-DISCONTINUITY')) {
        // 如果是最后一行，或者紧接着又是 DISCONTINUITY，则移除
        if (i == lines.length - 1) continue;
        if (clean.isNotEmpty && clean.last.startsWith('#EXT-X-DISCONTINUITY')) continue;
      }
      clean.add(lines[i]);
    }
    return clean;
  }

  String _getAbsoluteUrl(String path, Uri baseUri) {
    try {
      return baseUri.resolve(path).toString();
    } catch (e) {
      return path;
    }
  }

  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }
}