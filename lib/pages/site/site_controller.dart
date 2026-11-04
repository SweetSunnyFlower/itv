import 'package:get/get.dart';
import '../../app/models/site_model.dart';
import '../../app/services/storage_service.dart';

class SiteController extends GetxController {
  final _storage = StorageService();
  final sites = <SiteModel>[].obs;
  final currentIndex = 0.obs;
  final showAdult = false.obs;

  SiteModel get currentSite => sites[currentIndex.value];

  /// 过滤后的站点列表（用于展示）
  List<SiteModel> get displaySites =>
      showAdult.value ? sites : sites.where((s) => !s.isAdult).toList();

  void toggleAdult() {
    showAdult.value = !showAdult.value;
  }

  @override
  void onInit() {
    super.onInit();
    sites.value = _storage.getSites();
    currentIndex.value = _storage.getCurrentSiteIndex();
    if (currentIndex.value >= sites.length) currentIndex.value = 0;
  }

  void switchSite(int index) {
    currentIndex.value = index;
    _storage.saveCurrentSiteIndex(index);
  }

  void addSite(SiteModel site) {
    sites.add(site);
    _storage.saveSites(sites);
  }

  void removeSite(int index) {
    if (index < sites.length) {
      sites.removeAt(index);
      if (currentIndex.value >= sites.length) {
        currentIndex.value = sites.length - 1;
      }
      _storage.saveSites(sites);
      _storage.saveCurrentSiteIndex(currentIndex.value);
    }
  }

  void resetToDefault() {
    sites.value = List.from(StorageService.defaultSites);
    currentIndex.value = 0;
    _storage.saveSites(sites);
    _storage.saveCurrentSiteIndex(0);
  }
}
