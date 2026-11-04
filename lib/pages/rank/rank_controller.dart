import 'package:get/get.dart';
import '../../app/models/vod_model.dart';
import '../../app/services/api_service.dart';
import '../site/site_controller.dart';

class RankController extends GetxController {
  final _api = ApiService();
  final siteCtrl = Get.find<SiteController>();
  final rankList = <VodModel>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadRank();
    ever(siteCtrl.currentIndex, (_) => loadRank());
  }

  Future<void> loadRank() async {
    isLoading.value = true;
    final url = siteCtrl.currentSite.url;

    // 1. 获取排行列表（无图片）
    final rankResult = await _api.getRank(url);
    if (rankResult.list.isEmpty) {
      rankList.clear();
      isLoading.value = false;
      return;
    }

    // 取前 20 条
    final topItems = rankResult.list.take(20).toList();
    final ids = topItems.map((e) => e.vodId).toList();

    // 2. 批量获取详情（含图片）
    final details = await _api.getVodDetails(url, ids);
    final detailMap = {for (var d in details) d.vodId: d};

    // 合并：用详情数据替换，保持排行顺序
    final merged = <VodModel>[];
    for (final item in topItems) {
      merged.add(detailMap[item.vodId] ?? item);
    }

    rankList.value = merged;
    isLoading.value = false;
  }
}
