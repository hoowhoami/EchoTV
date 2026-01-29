import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/site.dart';
import 'config_service.dart';
import '../providers/settings_provider.dart';

final cmsServiceProvider = Provider((ref) => CmsService(ref));

class CmsService {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Accept': 'application/json, text/plain, */*',
    },
  ));

  CmsService(this._ref);

  Future<List<VideoDetail>> search(SiteConfig site, String query, {int page = 1}) async {
    try {
      final url = '${site.api}?ac=videolist&wd=${Uri.encodeComponent(query)}&pg=$page';
      final response = await _dio.get(url);

      if (response.data == null) {
        return [];
      }

      // Web 平台兼容：确保 data 是 Map
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

      // 兼容性处理：list 字段可能是数组或字符串
      final listData = data['list'];
      if (listData == null) {
        return [];
      }

      // 如果 list 是字符串，尝试解析为 JSON
      List list;
      if (listData is String) {
        try {
          final decoded = jsonDecode(listData);
          if (decoded is List) {
            list = decoded;
          } else {
            return [];
          }
        } catch (e) {
          return [];
        }
      } else if (listData is List) {
        list = listData;
      } else {
        return [];
      }

      final List<VideoDetail> results = [];
      final isTeenageMode = _ref.read(teenageModeProvider);
      final filteredKeywords = [
        '成人', '福利', '伦理', '黄色', '性感', '禁片', '写真', '三级', '情色', 
        '美女', '微拍', '自拍', '模特', '内衣', '丝袜', '限制级', '激情', 
        '18+', 'xxx', 'av', '偷拍', '女主播', '诱惑', '无码', '有码'
      ];

      for (var item in list) {
        try {
          final detail = _parseVideoItem(item, site);
          if (detail.playGroups.isNotEmpty) {
            bool shouldFilter = false;
            if (isTeenageMode) {
              final content = '${detail.title}${detail.typeName ?? ''}${detail.sourceName}'.toLowerCase();
              for (var kw in filteredKeywords) {
                if (content.contains(kw)) {
                  shouldFilter = true;
                  break;
                }
              }
            }
            if (!shouldFilter) {
              results.add(detail);
            }
          }
        } catch (e) {
          // Skip invalid items
        }
      }

      // 第一页请求成功后，如果是搜索且有多页，全并发抓取后续页
      if (page == 1) {
        try {
          final pageCountData = data['pagecount'];
          if (pageCountData != null) {
            int pageCount = 1;
            if (pageCountData is int) {
              pageCount = pageCountData;
            } else if (pageCountData is String) {
              pageCount = int.tryParse(pageCountData) ?? 1;
            }

            if (pageCount > 1) {
              int limit = pageCount > 3 ? 3 : pageCount;
              final futures = <Future<List<VideoDetail>>>[];
              for (int i = 2; i <= limit; i++) {
                futures.add(search(site, query, page: i));
              }
              final moreResults = await Future.wait(futures);
              for (var extra in moreResults) {
                results.addAll(extra);
              }
            }
          }
        } catch (e) {
          // Ignore pagination errors
        }
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  Future<List<VideoDetail>> searchAll(List<SiteConfig> sites, String query) async {
    final activeSites = sites.where((s) => !s.disabled).toList();
    if (activeSites.isEmpty) {
      return [];
    }

    // 真正的全并发搜索所有站点
    final results = await Future.wait(
      activeSites.map((site) async {
        try {
          final siteResults = await search(site, query);
          return siteResults;
        } catch (e) {
          return <VideoDetail>[];
        }
      })
    );

    // 过滤掉没有任何集数的无效资源
    final allResults = results.expand((x) => x).where((res) => res.playGroups.isNotEmpty).toList();

    return allResults;
  }

  /// 流式搜索：并发搜索所有站点，每个站点有结果就立即返回
  /// 返回的 Stream 会持续发送累积的结果列表
  Stream<List<VideoDetail>> searchAllStream(List<SiteConfig> sites, String query) async* {
    final activeSites = sites.where((s) => !s.disabled).toList();
    if (activeSites.isEmpty) {
      yield [];
      return;
    }

    final allResults = <VideoDetail>[];
    final controller = StreamController<List<VideoDetail>>();
    int completedCount = 0;

    // 并发搜索所有站点
    for (var site in activeSites) {
      search(site, query).then((siteResults) {
        if (siteResults.isNotEmpty) {
          // 过滤掉没有任何集数的无效资源
          final validResults = siteResults.where((res) => res.playGroups.isNotEmpty).toList();
          if (validResults.isNotEmpty) {
            allResults.addAll(validResults);
            controller.add(List.from(allResults));
          }
        }
        completedCount++;
        if (completedCount == activeSites.length) {
          controller.close();
        }
      }).catchError((_) {
        completedCount++;
        if (completedCount == activeSites.length) {
          controller.close();
        }
      });
    }

    yield* controller.stream;
  }

  Future<VideoDetail?> getDetail(SiteConfig site, String id) async {
    try {
      final url = '${site.api}?ac=videolist&ids=$id';
      final response = await _dio.get(url);

      if (response.data == null) return null;

      // Web 平台兼容：确保 data 是 Map
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

      // 兼容性处理：list 字段可能是数组或字符串
      final listData = data['list'];
      if (listData == null) return null;

      List list;
      if (listData is String) {
        try {
          list = jsonDecode(listData) as List;
        } catch (e) {
          return null;
        }
      } else if (listData is List) {
        list = listData;
      } else {
        return null;
      }

      if (list.isEmpty) return null;

      return _parseVideoItem(list[0], site);
    } catch (e) {
      return null;
    }
  }

  VideoDetail _parseVideoItem(Map<String, dynamic> item, SiteConfig site) {
    List<PlayGroup> playGroups = [];
    final String playFrom = (item['vod_play_from'] ?? '').toString();
    final String playUrl = (item['vod_play_url'] ?? '').toString();

    if (playFrom.isNotEmpty && playUrl.isNotEmpty) {
      final froms = playFrom.split('\$\$\$');
      final urlsGroups = playUrl.split('\$\$\$');

      for (int i = 0; i < froms.length; i++) {
        if (i >= urlsGroups.length) break;
        List<String> urls = [];
        List<String> titles = [];
        final episodesList = urlsGroups[i].split('#');
        for (var ep in episodesList) {
          final parts = ep.split('\$');
          if (parts.length == 2) {
            titles.add(parts[0].trim());
            urls.add(parts[1].trim());
          } else if (parts.length == 1 && parts[0].isNotEmpty) {
            titles.add('正片');
            urls.add(parts[0].trim());
          }
        }
        if (urls.isNotEmpty) {
          playGroups.add(PlayGroup(name: froms[i], urls: urls, titles: titles));
        }
      }
    }

    // 单个资源条目下只选取最长的一条线路
    if (playGroups.isNotEmpty) {
      playGroups.sort((a, b) => b.urls.length.compareTo(a.urls.length));
      playGroups = [playGroups.first];
    }

    return VideoDetail(
      id: item['vod_id'].toString(),
      title: (item['vod_name'] ?? '').toString().trim(),
      poster: item['vod_pic'] ?? '',
      playGroups: playGroups,
      source: site.key,
      sourceName: site.name,
      year: item['vod_year']?.toString(),
      desc: (item['vod_content'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '').trim(),
      typeName: item['type_name'],
    );
  }
}
