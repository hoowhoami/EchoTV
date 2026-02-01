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
    // 关键修复：处理所有标签内的 URI 属性（如加密 Key 和初始化分片）
    // 如果不处理这些，播放器会去 localhost 根目录请求它们，导致 404
    content = content.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (match) {
      final uri = match.group(1)!;
      return 'URI="${_getAbsoluteUrl(uri, baseUri)}"';
    });

    final lines = content.split('\n');
    final result = <String>[];
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        final durationMatch = RegExp(r'#EXTINF:(\d+(\.\d+)?)').firstMatch(line);
        if (durationMatch != null) {
          final duration = double.tryParse(durationMatch.group(1) ?? '0') ?? 0;
          if (duration < 5.0 && result.length < 20) {
             if (i + 1 < lines.length && !lines[i+1].startsWith('#')) {
                final nextLine = lines[i+1].trim();
                if (nextLine.contains('ads') || nextLine.contains('union') || nextLine.contains('.mp4')) {
                  debugPrint('🚫 AdBlock: Skipped ad segment (${duration}s): $nextLine');
                  i++; 
                  continue;
                }
             }
          }
        }
      }

      if (!line.startsWith('#')) {
        result.add(_getAbsoluteUrl(line, baseUri));
      } else {
        result.add(line);
      }
    }
    return result.join('\n');
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