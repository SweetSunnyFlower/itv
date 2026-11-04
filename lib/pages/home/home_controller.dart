import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../app/models/vod_model.dart';
import '../../app/services/api_service.dart';
import '../site/site_controller.dart';

class HomeController extends GetxController {
  final _api = ApiService();
  final siteCtrl = Get.find<SiteController>();

  final categories = <VodCategory>[].obs;
  final isLoading = true.obs;
  final featuredList = <VodModel>[].obs;
  final categoryVods = <int, List<VodModel>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    ever(siteCtrl.currentIndex, (_) => loadData());
    loadData();
  }

  Future<void> loadData() async {
    isLoading.value = true;
    categoryVods.clear();
    featuredList.clear();

    final url = siteCtrl.currentSite.url;
    debugPrint('Loading data from: $url');

    // 1. 先加载最新数据（不带分类），同时也能获取分类列表
    final latest = await _api.getVodList(url, page: 1);
    debugPrint('Latest loaded: ${latest.list.length} items, ${latest.categories.length} categories');

    featuredList.value = latest.list.take(5).toList();

    // 获取分类 —— 优先用 detail 返回的，否则单独请求
    List<VodCategory> cats = latest.categories;
    if (cats.isEmpty) {
      cats = await _api.getCategories(url);
    }
    categories.value = cats;

    // 如果最新列表有数据，先显示出来，不再阻塞
    if (latest.list.isNotEmpty) {
      isLoading.value = false;
    }

    // 2. 筛选出子分类（type_pid > 0），取前6个分批加载
    final subCats = cats.where((c) => c.typePid > 0).take(6).toList();
    // 如果没有子分类就用全部分类
    final loadCats = subCats.isNotEmpty ? subCats : cats.take(6).toList();

    // 串行加载每个分类（避免并发过多被限流）
    final Map<int, List<VodModel>> map = {};
    for (final c in loadCats) {
      try {
        final result = await _api.getVodList(url, page: 1, typeId: c.typeId);
        if (result.list.isNotEmpty) {
          map[c.typeId] = result.list;
          // 每加载一个分类就更新UI
          categoryVods.value = Map.from(map);
        }
      } catch (e) {
        debugPrint('Load category ${c.typeName} failed: $e');
      }
    }

    isLoading.value = false;
  }

  String getCategoryName(int typeId) {
    return categories.firstWhereOrNull((c) => c.typeId == typeId)?.typeName ?? '';
  }
}
