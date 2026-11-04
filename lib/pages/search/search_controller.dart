import 'package:get/get.dart';
import '../../app/models/vod_model.dart';
import '../../app/services/api_service.dart';
import '../../app/services/storage_service.dart';
import '../site/site_controller.dart';

class SearchController extends GetxController {
  final _api = ApiService();
  final siteCtrl = Get.find<SiteController>();
  final _storage = StorageService();

  final results = <VodModel>[].obs;
  final isLoading = false.obs;
  final keyword = ''.obs;
  int _page = 1;
  int _pageCount = 1;

  Future<void> search(String text) async {
    if (text.trim().isEmpty) return;
    keyword.value = text.trim();
    // 保存搜索历史
    _storage.addSearchHistory(keyword.value);
    _page = 1;
    isLoading.value = true;
    final url = siteCtrl.currentSite.url;
    final result = await _api.search(url, keyword.value, page: _page);
    results.value = result.list;
    _pageCount = result.pagecount;
    isLoading.value = false;
  }

  Future<void> loadMore() async {
    if (isLoading.value || _page >= _pageCount) return;
    _page++;
    isLoading.value = true;
    final url = siteCtrl.currentSite.url;
    final result = await _api.search(url, keyword.value, page: _page);
    results.addAll(result.list);
    isLoading.value = false;
  }

  bool get hasMore => _page < _pageCount;
}
