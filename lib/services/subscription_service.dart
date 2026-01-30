import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:bs58/bs58.dart';
import 'dart:convert';
import '../models/site.dart';
import '../models/live.dart';
import '../models/subscription.dart';
import 'config_service.dart';

final subscriptionServiceProvider = Provider((ref) => SubscriptionService(ref.read(configServiceProvider)));

class SubscriptionService {
  final Dio _dio = Dio();
  final ConfigService _configService;

  SubscriptionService(this._configService);

  Future<void> syncFromUrl(String url, {String? subscriptionId}) async {
    try {
      final response = await _dio.get(url);
      var data = response.data;
      
      // 如果返回的是字符串，尝试 Base58 解码（参考 LunaTV）
      if (data is String) {
        data = _tryDecode(data);
        try {
          data = jsonDecode(data);
        } catch (e) {
          debugPrint('JSON 解析失败: $e');
        }
      }

      if (data is Map<String, dynamic>) {
        await importFromJson(data, subscriptionId: subscriptionId);
      }
    } catch (e) {
      throw Exception('订阅同步失败: $e');
    }
  }

  String _tryDecode(String content) {
    try {
      // 尝试 Base58 解码
      final decodedBytes = base58.decode(content.trim());
      return utf8.decode(decodedBytes);
    } catch (e) {
      // 如果解码失败，可能原本就是明文 JSON，直接返回
      debugPrint('Base58 解码跳过或失败: $e');
      return content;
    }
  }

  Future<void> refreshSubscription(Subscription sub) async {
    // 1. 先清除该订阅旧数据
    await _removeSubscriptionData(sub.id);
    
    // 2. 重新下载
    await syncFromUrl(sub.url, subscriptionId: sub.id);
    
    // 3. 更新时间
    final subs = await _configService.getSubscriptions();
    final index = subs.indexWhere((s) => s.id == sub.id);
    if (index != -1) {
      subs[index] = subs[index].copyWith(lastUpdate: DateTime.now());
      await _configService.saveSubscriptions(subs);
    }
  }

  Future<void> _removeSubscriptionData(String subId) async {
    await _configService.removeSubscriptionData(subId);
  }

  Future<void> checkAndRefreshAutoUpdateSubscriptions() async {
    final subs = await _configService.getSubscriptions();
    final now = DateTime.now();
    for (var sub in subs) {
      if (sub.autoUpdate && sub.enabled) {
        // 如果没更新过，或者超过 24 小时
        if (sub.lastUpdate == null || now.difference(sub.lastUpdate!).inHours >= 24) {
          try {
            await refreshSubscription(sub);
          } catch (e) {
            debugPrint('自动更新订阅失败 (${sub.name}): $e');
          }
        }
      }
    }
  }

  Future<void> importFromJson(Map<String, dynamic> json, {String? subscriptionId}) async {
    // 1. 处理视频源
    if (json['api_site'] != null) {
      final Map<String, dynamic> sitesMap = json['api_site'];
      final List<SiteConfig> newSites = [];
      sitesMap.forEach((key, val) {
        newSites.add(SiteConfig(
          key: key,
          name: val['name'] ?? key,
          api: val['api'] ?? '',
          detail: val['detail'],
          from: subscriptionId != null ? 'subscription' : 'custom',
          subscriptionId: subscriptionId,
        ));
      });
      final currentSites = await _configService.getSitesAll();
      final mergedSites = [...currentSites, ...newSites];
      // 以 API 为唯一标识去重，保留后面的（新的）
      final uniqueSites = { for (var s in mergedSites) s.api : s }.values.toList();
      await _configService.saveSites(uniqueSites);
    }

    // 2. 处理直播源
    if (json['lives'] != null) {
      final Map<String, dynamic> livesMap = json['lives'];
      final List<LiveSource> newLives = [];
      livesMap.forEach((key, val) {
        newLives.add(LiveSource(
          key: key,
          name: val['name'] ?? key,
          url: val['url'] ?? '',
          from: subscriptionId != null ? 'subscription' : 'custom',
          subscriptionId: subscriptionId,
        ));
      });
      final currentLives = await _configService.getLiveSourcesAll();
      final mergedLives = [...currentLives, ...newLives];
      // 以 URL 为唯一标识去重
      final uniqueLives = { for (var l in mergedLives) l.url : l }.values.toList();
      await _configService.saveLiveSources(uniqueLives);
    }

    // 3. 处理分类映射
    if (json['custom_category'] != null) {
      final List<dynamic> catsList = json['custom_category'];
      final List<CustomCategory> newCats = catsList.map((c) => CustomCategory.fromJson(c as Map<String, dynamic>).copyWith(
        from: subscriptionId != null ? 'subscription' : 'custom',
        subscriptionId: subscriptionId,
      )).toList().cast<CustomCategory>();
      
      final currentCats = await _configService.getCategoriesAll();
      final mergedCats = [...currentCats, ...newCats];
      // 以 name 为唯一标识去重
      final uniqueCats = { for (var c in mergedCats) c.name : c }.values.toList();
      await _configService.saveCategories(uniqueCats);
    }
  }
}

extension CustomCategoryExtension on CustomCategory {
  CustomCategory copyWith({
    String? name,
    String? type,
    String? query,
    String? from,
    bool? disabled,
    String? subscriptionId,
  }) {
    return CustomCategory(
      name: name ?? this.name,
      type: type ?? this.type,
      query: query ?? this.query,
      from: from ?? this.from,
      disabled: disabled ?? this.disabled,
      subscriptionId: subscriptionId ?? this.subscriptionId,
    );
  }
}

