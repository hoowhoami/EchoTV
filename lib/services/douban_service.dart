import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/movie.dart';
import 'config_service.dart';

final doubanServiceProvider = Provider((ref) => DoubanService(ref));

class DoubanService {
  final Ref _ref;

  final Dio _dio = Dio(BaseOptions(
    headers: {
      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
      'Referer': 'https://m.douban.com/',
    },
  ));

  DoubanService(this._ref);

  Future<String> getDoubanBase(String subdomain) async {
    final configService = _ref.read(configServiceProvider);
    final proxyType = await configService.getDoubanProxyType();

    switch (proxyType) {
      case 'tencent-cmlius':
        return 'https://$subdomain.douban.cmliussss.net';
      case 'direct':
        return 'https://$subdomain.douban.com';
      default:
        return 'https://$subdomain.douban.cmliussss.net';
    }
  }

  Future<DoubanSubject?> getDetail(String id) async {
    try {
      final baseUrl = await getDoubanBase('m');
      final response = await _dio.get('$baseUrl/rexxar/api/v2/movie/$id');

      Map<String, dynamic> data;
      if (response.data is String) {
        try {
          data = jsonDecode(response.data);
        } catch (e) {
          return null;
        }
      } else if (response.data is Map) {
        data = Map<String, dynamic>.from(response.data);
      } else {
        return null;
      }

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
        final baseUrl = await getDoubanBase('m');
        final response = await _dio.get('$baseUrl/rexxar/api/v2/tv/$id');

        Map<String, dynamic> data;
        if (response.data is String) {
          try {
            data = jsonDecode(response.data);
          } catch (e) {
            return null;
          }
        } else if (response.data is Map) {
          data = Map<String, dynamic>.from(response.data);
        } else {
          return null;
        }

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
      final baseUrl = await getDoubanBase('movie');
      final response = await _dio.get('$baseUrl/j/search_subjects', queryParameters: {
        'type': type,
        'tag': tag,
        'page_limit': 24,
        'page_start': pageStart,
      });

      Map<String, dynamic> data;
      if (response.data is String) {
        try {
          data = jsonDecode(response.data);
        } catch (e) {
          return [];
        }
      } else if (response.data is Map) {
        data = Map<String, dynamic>.from(response.data);
      } else {
        return [];
      }

      final subjects = data['subjects'] as List;
      return subjects.map((s) => DoubanSubject.fromJson(Map<String, dynamic>.from(s))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<DoubanSubject>> getRexxarList(String kind, String category, String type, {int pageStart = 0, int count = 24}) async {
    try {
      final baseUrl = await getDoubanBase('m');
      final response = await _dio.get('$baseUrl/rexxar/api/v2/subject/recent_hot/$kind', queryParameters: {
        'start': pageStart,
        'count': count,
        'category': category,
        'type': type,
      });

      Map<String, dynamic> data;
      if (response.data is String) {
        try {
          data = jsonDecode(response.data);
        } catch (e) {
          return [];
        }
      } else if (response.data is Map) {
        data = Map<String, dynamic>.from(response.data);
      } else {
        return [];
      }

      final items = data['items'] as List;
      return items.map((s) => DoubanSubject.fromJson(Map<String, dynamic>.from(s))).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<DoubanSubject>> getRecommendList(String kind, Map<String, String> filters, {int pageStart = 0}) async {
    try {
      final baseUrl = await getDoubanBase('m');
      final tags = <String>[];
      final selectedCategories = <String, String>{};

      // Some callers may pass the filter under the legacy key 'type'.
      // Support both for robustness.
      final category = filters['category'] ?? filters['type'];
      final format = filters['format'];
      final region = filters['region'];
      final year = filters['year'];
      final platform = filters['platform'];
      final label = filters['label'];
      final sort = filters['sort'];

      if (category != null && category != 'all' && category.isNotEmpty) {
        tags.add(category);
        selectedCategories['类型'] = category;
      }
      if (format != null && format != 'all' && format.isNotEmpty) {
        if (category == null || category.isEmpty || category == 'all') {
          tags.add(format);
        }
        selectedCategories['形式'] = format;
      }
      if (region != null && region != 'all' && region.isNotEmpty) {
        tags.add(region);
        selectedCategories['地区'] = region;
      }
      if (label != null && label != 'all' && label.isNotEmpty) {
        tags.add(label);
      }
      if (year != null && year != 'all' && year.isNotEmpty) {
        tags.add(year);
      }
      if (platform != null && platform != 'all' && platform.isNotEmpty) {
        tags.add(platform);
      }

      final queryParams = {
        'refresh': '0',
        'start': pageStart,
        'count': 24,
        'uncollect': 'false',
        'score_range': '0,10',
        'tags': tags.join(','),
        'selected_categories': jsonEncode(selectedCategories),
      };

      if (sort != null && sort != 'T' && sort.isNotEmpty) {
        queryParams['sort'] = sort;
      }

      final response = await _dio.get('$baseUrl/rexxar/api/v2/$kind/recommend', queryParameters: queryParams);

      Map<String, dynamic> data;
      if (response.data is String) {
        try {
          data = jsonDecode(response.data);
        } catch (e) {
          return [];
        }
      } else if (response.data is Map) {
        data = Map<String, dynamic>.from(response.data);
      } else {
        return [];
      }

      final items = data['items'] as List;
      return items.where((i) => i['type'] == 'movie' || i['type'] == 'tv').map((s) => DoubanSubject.fromJson(s)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<DoubanSubject>> search(String query) async {
    try {
      final baseUrl = await getDoubanBase('m');
      final response = await _dio.get('$baseUrl/rexxar/api/v2/search/subjects', queryParameters: {
        'q': query,
        'start': 0,
        'count': 20,
      });

      Map<String, dynamic> data;
      if (response.data is String) {
        data = jsonDecode(response.data);
      } else {
        data = Map<String, dynamic>.from(response.data);
      }

      final items = data['items'] as List;
      return items.where((i) => i['type'] == 'movie' || i['type'] == 'tv').map((s) => DoubanSubject.fromJson(s)).toList();
    } catch (e) {
      return [];
    }
  }
}
