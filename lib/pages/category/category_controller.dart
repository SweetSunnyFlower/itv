import 'package:get/get.dart';
import '../../app/models/vod_model.dart';
import '../../app/services/api_service.dart';
import '../site/site_controller.dart';

class CategoryController extends GetxController {
  final _api = ApiService();
  final siteCtrl = Get.find<SiteController>();

  final allCategories = <VodCategory>[].obs;
  final parentCategories = <VodCategory>[].obs;
  final selectedParentId = 0.obs;
  final selectedChildId = 0.obs;
  final selectedYear = ''.obs;

  final vodList = <VodModel>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final currentPage = 1.obs;
  final hasMore = true.obs;

  /// 构造年份列表：全部 + 2026~1960
  List<String> get years {
    final list = <String>[''];
    for (var y = DateTime.now().year; y >= 1960; y--) {
      list.add(y.toString());
    }
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    loadCategories();
    ever(siteCtrl.currentIndex, (_) => loadCategories());
  }

  Future<void> loadCategories() async {
    isLoading.value = true;
    final url = siteCtrl.currentSite.url;
    final cats = await _api.getCategoryTree(url);
    allCategories.value = cats;
    parentCategories.value = cats.where((c) => c.typePid == 0).toList();
    if (parentCategories.isNotEmpty) {
      selectedParentId.value = parentCategories.first.typeId;
      // 默认选择第一个子分类
      final children = allCategories.where((c) => c.typePid == selectedParentId.value).toList();
      selectedChildId.value = children.isNotEmpty ? children.first.typeId : 0;
      selectedYear.value = '';
      await loadVods(refresh: true);
    } else {
      isLoading.value = false;
    }
  }

  List<VodCategory> get childCategories {
    return allCategories.where((c) => c.typePid == selectedParentId.value).toList();
  }

  void selectParent(int typeId) {
    if (selectedParentId.value == typeId) return;
    selectedParentId.value = typeId;
    // 默认选择第一个子分类
    final children = allCategories.where((c) => c.typePid == typeId).toList();
    selectedChildId.value = children.isNotEmpty ? children.first.typeId : 0;
    selectedYear.value = '';
    loadVods(refresh: true);
  }

  void selectChild(int typeId) {
    if (selectedChildId.value == typeId) return;
    selectedChildId.value = typeId;
    loadVods(refresh: true);
  }

  void selectYear(String year) {
    if (selectedYear.value == year) return;
    selectedYear.value = year;
    loadVods(refresh: true);
  }

  int get _filterTypeId {
    // 选了子分类用子分类ID，否则用父分类ID
    if (selectedChildId.value > 0) {
      return selectedChildId.value;
    }
    return selectedParentId.value;
  }

  Future<void> loadVods({bool refresh = false}) async {
    if (refresh) {
      currentPage.value = 1;
      hasMore.value = true;
      vodList.clear();
      isLoading.value = true;
    } else {
      if (!hasMore.value || isLoadingMore.value) return;
      isLoadingMore.value = true;
    }

    final url = siteCtrl.currentSite.url;
    final typeId = _filterTypeId;
    final year = selectedYear.value;

    VodListResponse result;

    if (year.isEmpty) {
      // ac=detail 支持父分类ID，且直接返回图片，不需要二次请求
      result = await _api.getVodList(url, page: currentPage.value, typeId: typeId);
    } else {
      // 有年份筛选时用 ac=filter，再批量补图
      final filterTypeId = typeId > 0 ? typeId : selectedParentId.value;
      final filterResult = await _api.filter(url, typeId: filterTypeId, year: year, page: currentPage.value);
      if (filterResult.list.isNotEmpty) {
        final ids = filterResult.list.map((e) => e.vodId).toList();
        final details = await _api.getVodDetails(url, ids);
        final detailMap = {for (var d in details) d.vodId: d};
        final merged = filterResult.list.map((item) => detailMap[item.vodId] ?? item).toList();
        result = VodListResponse(
          list: merged,
          page: filterResult.page,
          pagecount: filterResult.pagecount,
          total: filterResult.total,
        );
      } else {
        result = filterResult;
      }
    }

    if (result.list.isNotEmpty) {
      if (refresh) {
        vodList.value = result.list;
      } else {
        vodList.addAll(result.list);
      }
      currentPage.value++;
      hasMore.value = currentPage.value <= result.pagecount;
    } else {
      hasMore.value = false;
    }

    isLoading.value = false;
    isLoadingMore.value = false;
  }
}
