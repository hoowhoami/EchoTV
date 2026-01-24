import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live.dart';

final liveServiceProvider = Provider((ref) => LiveService(ref));

class LiveService {
  final Ref _ref;
  final Dio _dio = Dio();

  LiveService(this._ref);

  Future<List<LiveChannel>> fetchChannels(String url) async {
    try {
      final response = await _dio.get(url);
      final content = response.data.toString();
      return _parseM3U(content);
    } catch (e) {
      return [];
    }
  }

  List<LiveChannel> _parseM3U(String content) {
    final List<LiveChannel> channels = [];
    final lines = content.split('\n');
    
    String? currentName;
    String? currentGroup;
    String? currentLogo;

    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('#EXTINF:')) {
        final nameMatch = RegExp(r',(.+)$').firstMatch(line);
        currentName = nameMatch?.group(1)?.trim();
        final groupMatch = RegExp(r'group-title="([^"]+)"').firstMatch(line);
        currentGroup = groupMatch?.group(1);
        final logoMatch = RegExp(r'tvg-logo="([^"]+)"').firstMatch(line);
        currentLogo = logoMatch?.group(1);
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        if (currentName != null) {
          channels.add(LiveChannel(
            name: currentName,
            url: line,
            group: currentGroup,
            logo: currentLogo,
          ));
        }
        currentName = null;
        currentGroup = null;
        currentLogo = null;
      }
    }
    return channels;
  }
}
