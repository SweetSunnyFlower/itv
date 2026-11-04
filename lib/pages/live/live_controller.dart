import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../app/models/live_channel.dart';
import '../../app/services/m3u_parser_service.dart';

class LiveController extends GetxController {
  // 分类列表
  final RxList<LiveCategory> categories = <LiveCategory>[].obs;

  // 当前选中分类
  final Rx<LiveCategory?> selectedCategory = Rx<LiveCategory?>(null);

  // 当前分类的频道列表
  final RxList<LiveChannel> channels = <LiveChannel>[].obs;

  // 分组后的频道
  final RxMap<String, List<LiveChannel>> groupedChannels = <String, List<LiveChannel>>{}.obs;

  // 当前选中的分组
  final RxString selectedGroup = ''.obs;

  // 搜索关键词
  final RxString searchKeyword = ''.obs;

  // 加载状态
  final RxBool isLoadingCategories = true.obs;
  final RxBool isLoadingChannels = false.obs;

  // 错误信息
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadCategories();
  }

  /// 加载分类列表
  Future<void> loadCategories() async {
    try {
      isLoadingCategories.value = true;
      errorMessage.value = '';

      final list = await LiveSourceService.fetchCategories();
      categories.value = list;

      // 默认选中第一个分类
      if (list.isNotEmpty) {
        selectCategory(list.first);
      }
    } catch (e) {
      debugPrint('加载分类失败: $e');
      errorMessage.value = '加载分类失败: ${e.toString()}';
    } finally {
      isLoadingCategories.value = false;
    }
  }

  /// 选择分类并加载频道
  Future<void> selectCategory(LiveCategory category) async {
    if (selectedCategory.value?.m3uUrl == category.m3uUrl) return;

    selectedCategory.value = category;
    await loadChannels(category.m3uUrl);
  }

  /// 加载频道列表
  Future<void> loadChannels(String m3uUrl) async {
    try {
      isLoadingChannels.value = true;
      errorMessage.value = '';
      channels.clear();
      groupedChannels.clear();

      final list = await LiveSourceService.fetchChannels(m3uUrl);
      channels.value = list;

      // 分组
      groupedChannels.value = LiveSourceService.groupChannels(list);

      // 设置默认分组
      if (groupedChannels.isNotEmpty) {
        selectedGroup.value = groupedChannels.keys.first;
      }
    } catch (e) {
      debugPrint('加载频道失败: $e');
      errorMessage.value = '加载频道失败: ${e.toString()}';
    } finally {
      isLoadingChannels.value = false;
    }
  }

  /// 选择分组
  void selectGroup(String group) {
    selectedGroup.value = group;
  }

  /// 搜索频道
  void search(String keyword) {
    searchKeyword.value = keyword;

    if (keyword.isEmpty) {
      groupedChannels.value = LiveSourceService.groupChannels(channels);
    } else {
      final filtered = LiveSourceService.searchChannels(channels, keyword);
      groupedChannels.value = LiveSourceService.groupChannels(filtered);
    }

    if (groupedChannels.isNotEmpty) {
      selectedGroup.value = groupedChannels.keys.first;
    }
  }
}
