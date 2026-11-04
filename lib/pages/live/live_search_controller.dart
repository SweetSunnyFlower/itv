import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../app/models/live_channel.dart';
import '../../app/services/m3u_parser_service.dart';

class LiveSearchController extends GetxController {
  // 搜索关键词
  final RxString keyword = ''.obs;

  // 搜索结果
  final RxList<LiveChannel> results = <LiveChannel>[].obs;

  // 加载状态
  final RxBool isLoading = false.obs;

  // 所有频道缓存
  List<LiveChannel> _allChannels = [];

  // 是否已加载
  bool _loaded = false;

  @override
  void onInit() {
    super.onInit();
    _loadAllChannels();
  }

  /// 加载所有直播源
  Future<void> _loadAllChannels() async {
    if (_loaded) return;

    try {
      isLoading.value = true;

      // 先获取所有分类
      final categories = await LiveSourceService.fetchCategories();

      // 并行加载所有分类的频道
      final futures = categories.map((cat) async {
        try {
          return await LiveSourceService.fetchChannels(cat.m3uUrl);
        } catch (e) {
          return <LiveChannel>[];
        }
      });

      final results = await Future.wait(futures);

      // 合并所有频道
      _allChannels = results.expand((list) => list).toList();
      _loaded = true;

      debugPrint('已加载 ${_allChannels.length} 个直播频道');
    } catch (e) {
      debugPrint('加载直播源失败: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// 搜索频道
  void search(String text) {
    keyword.value = text;

    if (text.isEmpty) {
      results.clear();
      return;
    }

    final lowerText = text.toLowerCase();
    results.value = _allChannels.where((channel) {
      return channel.name.toLowerCase().contains(lowerText) ||
          channel.group.toLowerCase().contains(lowerText) ||
          channel.country.toLowerCase().contains(lowerText);
    }).toList();
  }
}
