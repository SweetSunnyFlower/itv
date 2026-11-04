import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/vod_model.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    // 强制以纯文本接收，手动解析 JSON（因为很多站点 Content-Type 返回 text/html）
    responseType: ResponseType.plain,
  ));

  Map<String, dynamic> _parseJson(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final parsed = jsonDecode(data);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (e) {
        debugPrint('JSON parse error: $e');
      }
    }
    return {};
  }

  /// 获取影片列表（ac=detail，含图片等完整信息）
  Future<VodListResponse> getVodList(String baseUrl, {int page = 1, int? typeId}) async {
    try {
      final params = <String, dynamic>{
        'ac': 'detail',
        'pg': page,
      };
      if (typeId != null && typeId > 0) params['t'] = typeId;
      final reqUrl = '$baseUrl/api.php/provide/vod/';
      debugPrint('[API] GET $reqUrl params=$params');
      final response = await _dio.get(reqUrl, queryParameters: params);
      debugPrint('[API] Response(${response.statusCode}): ${response.data.toString().substring(0, (response.data.toString().length).clamp(0, 500))}');
      final data = _parseJson(response.data);
      if (data.isNotEmpty) {
        final result = VodListResponse.fromJson(data);
        debugPrint('[API] Parsed: ${result.list.length} items, total=${result.total}, page=${result.page}/${result.pagecount}');
        return result;
      }
      return VodListResponse();
    } catch (e) {
      debugPrint('[API] getVodList error ($baseUrl t=$typeId): $e');
      return VodListResponse();
    }
  }

  /// 获取分类列表（ac=list 轻量）
  Future<List<VodCategory>> getCategories(String baseUrl) async {
    try {
      final response = await _dio.get('$baseUrl/api.php/provide/vod/', queryParameters: {'ac': 'list'});
      final data = _parseJson(response.data);
      if (data.isNotEmpty) {
        return (data['class'] as List?)?.map((e) => VodCategory.fromJson(e)).toList() ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('getCategories error: $e');
      return [];
    }
  }

  /// 搜索
  Future<VodListResponse> search(String baseUrl, String keyword, {int page = 1}) async {
    try {
      final response = await _dio.get('$baseUrl/api.php/provide/vod/', queryParameters: {
        'ac': 'detail',
        'wd': keyword,
        'pg': page,
      });
      final data = _parseJson(response.data);
      if (data.isNotEmpty) {
        return VodListResponse.fromJson(data);
      }
      return VodListResponse();
    } catch (e) {
      debugPrint('search error: $e');
      return VodListResponse();
    }
  }

  /// 获取影片详情
  Future<VodModel?> getVodDetail(String baseUrl, int vodId) async {
    try {
      final response = await _dio.get('$baseUrl/api.php/provide/vod/', queryParameters: {
        'ac': 'detail',
        'ids': vodId,
      });
      final data = _parseJson(response.data);
      if (data.isNotEmpty) {
        final result = VodListResponse.fromJson(data);
        return result.list.isNotEmpty ? result.list.first : null;
      }
      return null;
    } catch (e) {
      debugPrint('getVodDetail error: $e');
      return null;
    }
  }

  /// 获取排行榜（ac=rank，不含图片）
  Future<VodListResponse> getRank(String baseUrl, {int page = 1}) async {
    try {
      final response = await _dio.get('$baseUrl/api.php/provide/vod/', queryParameters: {
        'ac': 'rank',
        'pg': page,
      });
      final data = _parseJson(response.data);
      if (data.isNotEmpty) {
        return VodListResponse.fromJson(data);
      }
      return VodListResponse();
    } catch (e) {
      debugPrint('getRank error: $e');
      return VodListResponse();
    }
  }

  /// 批量获取影片详情（含图片）
  Future<List<VodModel>> getVodDetails(String baseUrl, List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final response = await _dio.get('$baseUrl/api.php/provide/vod/', queryParameters: {
        'ac': 'detail',
        'ids': ids.join(','),
      });
      final data = _parseJson(response.data);
      if (data.isNotEmpty) {
        return VodListResponse.fromJson(data).list;
      }
      return [];
    } catch (e) {
      debugPrint('getVodDetails error: $e');
      return [];
    }
  }

  /// 获取分类树
  Future<List<VodCategory>> getCategoryTree(String baseUrl) async {
    try {
      final response = await _dio.get('$baseUrl/api.php/provide/vod/', queryParameters: {'ac': 'categoryTree'});
      final data = _parseJson(response.data);
      if (data.isNotEmpty) {
        return (data['class'] as List?)?.map((e) => VodCategory.fromJson(e)).toList() ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('getCategoryTree error: $e');
      return [];
    }
  }

  /// 分类筛选（ac=filter，不含图片）
  Future<VodListResponse> filter(String baseUrl, {required int typeId, String? area, String? year, int page = 1, int limit = 30}) async {
    try {
      final params = <String, dynamic>{
        'ac': 'filter',
        't': typeId,
        'limit': limit,
        'pg': page,
      };
      if (area != null && area.isNotEmpty) params['area'] = area;
      if (year != null && year.isNotEmpty) params['year'] = year;
      final response = await _dio.get('$baseUrl/api.php/provide/vod/', queryParameters: params);
      final data = _parseJson(response.data);
      if (data.isNotEmpty) {
        return VodListResponse.fromJson(data);
      }
      return VodListResponse();
    } catch (e) {
      debugPrint('filter error: $e');
      return VodListResponse();
    }
  }
}
