import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';

final doubanServiceProvider = Provider((ref) => DoubanService());

class DoubanService {
  final Dio _dio = Dio(BaseOptions(
    headers: {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
      'Referer': 'https://m.douban.com/',
    },
  ));

  String getDoubanBase(String subdomain) {
    // 恢复使用豆瓣镜像域名，确保在非 Web 环境下的稳定性
    return 'https://$subdomain.douban.cmliussss.net';
  }

  Future<DoubanSubject?> getDetail(String id) async {
    try {
      final baseUrl = getDoubanBase('m');
      final response = await _dio.get('$baseUrl/rexxar/api/v2/movie/$id');
      final data = response.data;
      
      return DoubanSubject(
        id: data['id'].toString(),
        title: data['title'] ?? '',
        rate: data['rating']?['value']?.toString() ?? '0.0',
        cover: data['pic']?['normal'] ?? data['pic']?['large'] ?? '',
        year: data['year']?.toString(),
        url: data['url'],
        description: data['intro'] ?? data['abstract'] ?? '',
      );
    } catch (e) {
      // Fallback for TV series
      try {
        final baseUrl = getDoubanBase('m');
        final response = await _dio.get('$baseUrl/rexxar/api/v2/tv/$id');
        final data = response.data;
        return DoubanSubject(
          id: data['id'].toString(),
          title: data['title'] ?? '',
          rate: data['rating']?['value']?.toString() ?? '0.0',
          cover: data['pic']?['normal'] ?? data['pic']?['large'] ?? '',
          year: data['year']?.toString(),
          url: data['url'],
          description: data['intro'] ?? data['abstract'] ?? '',
        );
      } catch (e2) {
        return null;
      }
    }
  }

  Future<List<DoubanSubject>> getList(String type, {String tag = '热门', int pageStart = 0}) async {
    try {
      final baseUrl = getDoubanBase('movie');
      final response = await _dio.get('$baseUrl/j/search_subjects', queryParameters: {
        'type': type,
        'tag': tag,
        'page_limit': 24,
        'page_start': pageStart,
      });
      
      final subjects = response.data['subjects'] as List;
      return subjects.map((s) => DoubanSubject.fromJson(s)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<DoubanSubject>> getRexxarList(String kind, String category, String type, {int pageStart = 0}) async {
    try {
      final baseUrl = getDoubanBase('m');
      final response = await _dio.get('$baseUrl/rexxar/api/v2/subject/recent_hot/$kind', queryParameters: {
        'start': pageStart,
        'count': 24,
        'category': category,
        'type': type,
      });
      
      final items = response.data['items'] as List;
      return items.map((s) => DoubanSubject.fromJson(s)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<DoubanSubject>> getRecommendList(String kind, Map<String, String> filters, {int pageStart = 0}) async {
    try {
      final baseUrl = getDoubanBase('m');
      final tags = <String>[];
      final selectedCategories = <String, String>{};

      if (filters['type'] != null && filters['type'] != 'all') {
        tags.add(filters['type']!);
        selectedCategories['类型'] = filters['type']!;
      }
      if (filters['region'] != null && filters['region'] != 'all') {
        tags.add(filters['region']!);
        selectedCategories['地区'] = filters['region']!;
      }
      
      final queryParams = {
        'refresh': '0',
        'start': pageStart,
        'count': 24,
        'uncollect': 'false',
        'score_range': '0,10',
        'tags': tags.join(','),
      };

      final response = await _dio.get('$baseUrl/rexxar/api/v2/$kind/recommend', queryParameters: queryParams);
      final items = response.data['items'] as List;
      return items.where((i) => i['type'] == 'movie' || i['type'] == 'tv').map((s) => DoubanSubject.fromJson(s)).toList();
    } catch (e) {
      return [];
    }
  }
}
